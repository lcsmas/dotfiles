import { useState, useEffect } from "react";
const { render, Box, Text, useInput, useApp } = await import("ink");
import { exec } from "child_process";

// Get the original working directory from command line args
const originalDir = process.argv[2] || process.cwd();

interface MenuItem {
  name: string;
  command: string;
}

const menuItems: MenuItem[] = [
  {
    name: "Create pull request",
    command: "~/dotfiles/lazygit/create-pr.sh",
  },
  { name: "Create release", command: "~/dotfiles/lazygit/release.sh" },
  { name: "Reboot system", command: "reboot" },
  {
    name: "Reboot on Windows",
    command: "sudo grub2-reboot 'osprober-efi-2E0C-C336' && sudo reboot",
  },
  {
    name: "Restore database (skip migrations)",
    command: "yarn --cwd ~/dev/workspace/ restore-db:skip-migrations",
  },
  {
    name: "Start admin (production)",
    command: "sudo ~/dev/workspace/packages/admin/start.sh -p",
  },
  {
    name: "Start admin (staging)",
    command: "sudo ~/dev/workspace/packages/admin/start.sh -s",
  },
  { name: "Start development server", command: "yarn dev" },
  {
    name: "Start Docker services",
    command:
      "docker compose -f ~/dev/workspace/docker-compose-custom.yml up -d",
  },
  { name: "Switch to Node 18", command: "nvm use 18" },
  {
    name: "Solve HelpTech",
    command: "~/dotfiles/linear-automation/analyze-ticket.sh",
  },
  {
    name: "Claude Code",
    command: "claude",
  },
];

function App() {
  const { exit } = useApp();
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [query, setQuery] = useState("");
  const [cursorVisible, setCursorVisible] = useState(true);

  useEffect(() => {
    const interval = setInterval(() => {
      setCursorVisible((prev) => !prev);
    }, 400);
    return () => clearInterval(interval);
  }, []);

  const filteredItems = menuItems.filter(
    (item) =>
      item.name.toLowerCase().includes(query.toLowerCase()) ||
      item.command.toLowerCase().includes(query.toLowerCase()),
  );

  useInput((input, key) => {
    if ((key.ctrl && input === "n") || key.downArrow) {
      setSelectedIndex((prev) =>
        prev < filteredItems.length - 1 ? prev + 1 : prev,
      );
    } else if ((key.ctrl && input === "p") || key.upArrow) {
      setSelectedIndex((prev) => (prev > 0 ? prev - 1 : prev));
    } else if (key.return) {
      if (filteredItems.length > 0) {
        const selected = filteredItems[selectedIndex] as MenuItem;
        exit();

        // Execute command in new tmux window, starting in the original directory
        const tmuxCommand = `tmux neww -n "${selected.command}" -c "${originalDir}" "zsh -ic '${selected.command}'; zsh -i"`;
        exec(tmuxCommand, (error) => {
          if (error) {
            console.error(`Error executing command: ${error.message}`);
          }
        });
      }
    } else if (key.escape || (key.ctrl && input === "c")) {
      exit();
    } else if (key.backspace || key.delete) {
      setQuery((prev) => prev.slice(0, -1));
      setSelectedIndex(0);
    } else if (!key.ctrl && !key.meta && input && input.length === 1) {
      setQuery((prev) => prev + input);
      setSelectedIndex(0);
    }
  });

  return (
    <Box padding={1} flexDirection="column">
      <Box marginBottom={1}>
        <Text>
          {"> "}
          {query ? (
            <>
              {query}
              <Text color="gray">{cursorVisible ? "█" : " "}</Text>
            </>
          ) : (
            <Text dimColor>
              {cursorVisible ? <Text backgroundColor="gray">S</Text> : "S"}
              elect command...
            </Text>
          )}
        </Text>
        {!query && <Text dimColor> (esc or ctrl+c to quit) </Text>}
      </Box>

      {filteredItems.length === 0 ? (
        <Text color="red">No matches found</Text>
      ) : (
        filteredItems.map((item, index) => (
          <Box key={index}>
            <Text color={index === selectedIndex ? "green" : ""}>
              {index === selectedIndex ? "> " : "  "}
            </Text>
            <Text color={index === selectedIndex ? "cyan" : ""}>
              {item.name}
            </Text>
            <Text dimColor> - {item.command}</Text>
          </Box>
        ))
      )}
    </Box>
  );
}

render(<App />);
