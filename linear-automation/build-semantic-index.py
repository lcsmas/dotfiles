#!/usr/bin/env python3
"""
Build semantic search index for HelpTech tickets using sentence-transformers.
This creates embeddings that enable true semantic search.
"""
import json
import pickle
import sys
from pathlib import Path
from sentence_transformers import SentenceTransformer

# Bot user names that should be excluded (automated messages)
BOT_EXTERNAL_USERS = {
    'Problème résolu',
    'Limitation technique'
}

def load_tickets(json_path):
    """Load tickets from JSON database"""
    print(f"Loading tickets from {json_path}...", file=sys.stderr)

    with open(json_path, 'r') as f:
        data = json.load(f)

    tickets = data['data']['issues']['nodes']
    print(f"Found {len(tickets)} tickets", file=sys.stderr)

    return tickets

def is_real_user_comment(comment):
    """
    Determine if a comment is from a real user (not bot noise).

    Returns True only if:
    - Has a real user OR
    - Has externalUser that is NOT a bot-generated user
    """
    has_user = comment.get('user') is not None
    has_external_user = comment.get('externalUser') is not None

    # If has user, it's real
    if has_user:
        return True

    # If has externalUser, check if it's a real user or bot
    if has_external_user:
        external_name = comment['externalUser'].get('name', '')
        # Exclude bot-generated externalUsers
        if external_name in BOT_EXTERNAL_USERS:
            return False
        return True

    # No user or externalUser = pure bot
    return False

def prepare_documents(tickets):
    """Prepare text documents for embedding"""
    documents = []
    total_comments = 0
    included_comments = 0

    for idx, ticket in enumerate(tickets):
        # Combine title, description, and comments into searchable text
        text_parts = []

        # Title (weighted more by repeating)
        title = ticket.get('title', '')
        text_parts.append(title)
        text_parts.append(title)  # Repeat for emphasis

        # Description
        description = ticket.get('description', '')
        if description:
            text_parts.append(description)

        # Comments - ONLY include real user comments
        for comment in ticket.get('comments', {}).get('nodes', []):
            total_comments += 1

            if is_real_user_comment(comment):
                body = comment.get('body', '')
                if body:
                    text_parts.append(body)
                    included_comments += 1

        # Combine all text
        full_text = ' '.join(text_parts)

        documents.append({
            'index': idx,
            'identifier': ticket['identifier'],
            'title': ticket['title'],
            'text': full_text
        })

    print(f"Comment filtering: {included_comments}/{total_comments} included", file=sys.stderr)

    return documents

def build_embeddings(documents, model_name='all-MiniLM-L6-v2'):
    """Build embeddings using sentence-transformers"""
    print(f"Loading model: {model_name}...", file=sys.stderr)
    print("(First run will download ~80MB model, cached for future use)", file=sys.stderr)

    model = SentenceTransformer(model_name)

    print(f"Encoding {len(documents)} tickets as documents...", file=sys.stderr)

    # Extract just the text for encoding
    texts = [doc['text'] for doc in documents]

    # Encode all documents using encode_document() for asymmetric search
    # This optimizes embeddings for corpus/document side of search
    embeddings = model.encode_document(
        texts,
        show_progress_bar=True,
        convert_to_numpy=True
    )

    # Add embeddings to documents
    for doc, embedding in zip(documents, embeddings):
        doc['embedding'] = embedding

    return documents, model

def save_index(documents, model, output_path):
    """Save index to disk"""
    print(f"Saving index to {output_path}...", file=sys.stderr)

    index = {
        'documents': documents,
        'model_name': model._model_name if hasattr(model, '_model_name') else 'all-MiniLM-L6-v2'
    }

    with open(output_path, 'wb') as f:
        pickle.dump(index, f, protocol=pickle.HIGHEST_PROTOCOL)

    print(f"Index saved successfully!", file=sys.stderr)

def main():
    script_dir = Path(__file__).parent
    json_path = script_dir / 'solved-tickets-database.json'
    index_path = script_dir / 'solved-tickets.index'

    # Check if JSON exists
    if not json_path.exists():
        print(f"Error: {json_path} not found", file=sys.stderr)
        print("Run ./fetch-solved-tickets.sh first", file=sys.stderr)
        sys.exit(1)

    # Check if index is already up-to-date
    if index_path.exists():
        json_mtime = json_path.stat().st_mtime
        index_mtime = index_path.stat().st_mtime

        if index_mtime > json_mtime:
            print("✓ Index is already up-to-date", file=sys.stderr)
            print(f"  (Delete {index_path} to force rebuild)", file=sys.stderr)
            return
        else:
            print("Database has been updated, rebuilding index...", file=sys.stderr)

    # Build index
    tickets = load_tickets(json_path)
    documents = prepare_documents(tickets)
    documents, model = build_embeddings(documents)
    save_index(documents, model, index_path)

    print(f"\n✓ Semantic index built successfully!", file=sys.stderr)
    print(f"  Documents: {len(documents)}", file=sys.stderr)
    print(f"  Model: {model._model_name if hasattr(model, '_model_name') else 'all-MiniLM-L6-v2'}", file=sys.stderr)
    print(f"  Index size: {index_path.stat().st_size / 1024 / 1024:.1f} MB", file=sys.stderr)

if __name__ == '__main__':
    main()
