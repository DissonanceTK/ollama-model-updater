# Ollama Model Updater

A lightweight zsh script that automatically updates all installed Ollama models to their latest versions with colored output and detailed progress reporting.

## Features

- **Automatic Updates**: Pull the latest versions of all installed models
- **Progress Tracking**: Real-time status updates with colored output and icons
- **Smart Caching**: Detects if models are already up-to-date
- **Skip List**: Exclude specific models from updates
- **Error Handling**: Gracefully handles daemon disconnections and pull failures
- **Detailed Summary**: Comprehensive statistics and per-category model lists
- **Accessibility**: Respects `NO_COLOR` environment variable and auto-detects terminal capabilities

## Prerequisites

- **Ollama**: Must be installed and running
  - Install from: https://ollama.ai
  - Start the daemon with: `ollama serve`

- **zsh**: Shell requirement (typically available on macOS and Linux)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/ollama-model-updater.git
   cd ollama-model-updater
   ```

2. Make the script executable:
   ```bash
   chmod +x ollama_update_models.sh
   ```

3. (Optional) Add to your PATH for global access:
   ```bash
   sudo ln -s "$(pwd)/ollama_update_models.sh" /usr/local/bin/ollama-update-models
   ```

## Usage

### Basic Usage
```bash
./ollama_update_models.sh
```

### Options

- `-q, --quiet`: Hide "OK (already current)" lines for cleaner output
- `--no-color`: Disable colored output (also respects `NO_COLOR` env var)
- `-h, --help`: Display usage information

### Examples

```bash
# Update all models with full output
./ollama_update_models.sh

# Quiet mode (suppress unchanged models)
./ollama_update_models.sh -q

# Disable colors
./ollama_update_models.sh --no-color

# Combine options
./ollama_update_models.sh --quiet --no-color
```

## Configuration

### Skipping Models

Edit the `skip_models` array in the script to exclude specific models from updates:

```bash
skip_models=(
  "model-to-skip:latest"
  "another-model:8b"
)
```

## Output

The script provides color-coded status indicators:

- **✓ OK** (Green): Model is already at the latest version
- **⬆ UPDATED** (Blue): Model was successfully updated with new version
- **⏭ SKIP** (Yellow): Model was skipped per configuration
- **✖ FAILED** (Red): Update attempt failed

### Example Output
```
✓  OK        llama3.2:latest (already current)
⬆  UPDATED   mistral:latest (abc123def456 → xyz789uvw012)
⏭  SKIP      example-model:latest
✖  FAILED    neural-chat:latest — connection timeout

==================== Summary ====================
Total: 4 | ⏭  Skipped: 1 | ⬆ Updated: 1 | ✓ No change: 1 | ✖  Failed: 1

Failed models: neural-chat:latest
Hint: If the daemon went down, run 'ollama serve' and rerun this script.
```

## Exit Codes

- `0`: All updates completed successfully (or no failures)
- `1`: One or more models failed to update
- `2`: Invalid command-line arguments

## Troubleshooting

### "Cannot connect to the Ollama daemon"
- Ensure Ollama is running: `ollama serve`
- Check that the Ollama socket is accessible

### "Connection reset" or "server not responding"
- The daemon may have crashed; restart it with `ollama serve`
- Run the script again to retry updates

### Models not updating
- Verify the model name matches what `ollama list` shows
- Check internet connectivity for pulling new versions
- Ensure sufficient disk space

## Contributing

Contributions are welcome! Please feel free to:
- Report bugs or issues
- Suggest improvements
- Submit pull requests

## License

This project is provided as-is. Feel free to use and modify for your needs.

## Related Links

- [Ollama Documentation](https://github.com/ollama/ollama)
- [Available Models](https://ollama.ai/library)
