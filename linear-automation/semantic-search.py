#!/usr/bin/env python3
"""
Semantic search for HelpTech tickets using prebuilt embeddings index.
"""
import json
import pickle
import sys
from pathlib import Path
import torch
from sentence_transformers import SentenceTransformer, util

def load_index(index_path):
    """Load prebuilt embeddings index"""
    with open(index_path, 'rb') as f:
        index = pickle.load(f)
    return index

def search(query, index, model, top_k=5):
    """
    Search for tickets matching the query using optimized semantic search.

    Args:
        query: Search query string
        index: Prebuilt embeddings index
        model: SentenceTransformer model
        top_k: Number of results to return

    Returns:
        List of (document, similarity_score) tuples
    """
    # Encode query using encode_query() for asymmetric search
    # This optimizes embeddings for the query side of search
    query_embedding = model.encode_query(query, convert_to_tensor=True)

    # Extract all document embeddings as tensor
    corpus_embeddings = torch.stack([
        torch.tensor(doc['embedding']) for doc in index['documents']
    ])

    # Use optimized semantic_search from sentence-transformers
    # This is much faster than manual cosine similarity
    hits = util.semantic_search(query_embedding, corpus_embeddings, top_k=top_k)[0]

    # Map hits back to documents
    results = []
    for hit in hits:
        doc = index['documents'][hit['corpus_id']]
        similarity = hit['score']
        results.append((doc, similarity))

    return results

def format_result(doc, similarity, rank):
    """Format search result for display"""
    return {
        'rank': rank,
        'identifier': doc['identifier'],
        'title': doc['title'],
        'similarity': float(similarity)
    }

def main():
    if len(sys.argv) < 2:
        print("Usage: semantic-search.py <query> [top_k]", file=sys.stderr)
        print("", file=sys.stderr)
        print("Examples:", file=sys.stderr)
        print("  semantic-search.py \"device not showing in loop\"", file=sys.stderr)
        print("  semantic-search.py \"wrong price\" 10", file=sys.stderr)
        sys.exit(1)

    query = sys.argv[1]
    top_k = int(sys.argv[2]) if len(sys.argv) > 2 else 5

    script_dir = Path(__file__).parent
    index_path = script_dir / 'solved-tickets.index'
    json_path = script_dir / 'solved-tickets-database.json'

    # Check if index exists
    if not index_path.exists():
        print(f"Error: Index not found at {index_path}", file=sys.stderr)
        print("Run ./build-semantic-index.py first to build the index", file=sys.stderr)
        sys.exit(1)

    # Load index
    print(f"Loading index from {index_path}...", file=sys.stderr)
    index = load_index(index_path)

    # Load model (uses cache, fast)
    model_name = index.get('model_name', 'all-MiniLM-L6-v2')
    print(f"Loading model: {model_name}...", file=sys.stderr)
    model = SentenceTransformer(model_name)

    # Search
    print(f"Searching for: \"{query}\"...", file=sys.stderr)
    results = search(query, index, model, top_k=top_k)

    # Load full ticket data for detailed results
    with open(json_path, 'r') as f:
        ticket_data = json.load(f)

    # Format results
    output = []
    for rank, (doc, similarity) in enumerate(results, 1):
        ticket_index = doc['index']
        full_ticket = ticket_data['data']['issues']['nodes'][ticket_index]

        # Extract only real user comments (same filtering as build script)
        BOT_EXTERNAL_USERS = {'Problème résolu', 'Limitation technique'}
        comments = []
        for comment in full_ticket.get('comments', {}).get('nodes', []):
            has_user = comment.get('user') is not None
            has_external_user = comment.get('externalUser') is not None

            is_real = False
            if has_user:
                is_real = True
            elif has_external_user:
                external_name = comment['externalUser'].get('name', '')
                if external_name not in BOT_EXTERNAL_USERS:
                    is_real = True

            if is_real:
                author = "Unknown"
                if comment.get('user'):
                    author = comment['user'].get('name', 'Unknown User')
                elif comment.get('externalUser'):
                    author = comment['externalUser'].get('name', 'Unknown External')

                comments.append({
                    'author': author,
                    'body': comment.get('body', '')
                })

        output.append({
            'rank': rank,
            'similarity': float(similarity),
            'identifier': doc['identifier'],
            'title': doc['title'],
            'description': full_ticket.get('description'),
            'url': full_ticket.get('url'),
            'comments': comments
        })

    # Output JSON
    print(json.dumps(output, indent=2, ensure_ascii=False))

if __name__ == '__main__':
    main()
