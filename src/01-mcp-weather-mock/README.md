# MCP Weather Mock Server

A mock weather MCP (Model Context Protocol) server that provides weather data for cities across multiple countries.

## Quickstart

### 1. Create virtual environment

```bash
python -m venv .venv
```

### 2. Activate virtual environment

**Linux / macOS / Codespace:**
```bash
source .venv/bin/activate
```

**Windows (PowerShell):**
```powershell
.venv\Scripts\Activate.ps1
```

**Windows (Command Prompt):**
```cmd
.venv\Scripts\activate.bat
```

### 3. Install dependencies

```bash
pip install -r requirements.txt
```

### 4. Run the server

```bash
python main.py
```

The server starts at `http://localhost:8000`.

## Docker Deployment

### Build the Docker image

```bash
docker build -t mcp-weather-mock .
```

### Run the container

```bash
docker run -d -p 8000:8000 --name mcp-weather mcp-weather-mock
```

### Stop and remove the container

```bash
docker stop mcp-weather
docker rm mcp-weather
```

### View container logs

```bash
docker logs mcp-weather
```

## MCP Client Connection

### Connect from an MCP client

Use the streamable HTTP endpoint:

```
http://localhost:8000/mcp
```

## Available Tools

| Tool | Description |
|------|-------------|
| `get_cities` | Get list of cities for a country (usa, canada, uk, australia, india, portugal, thailand) |
| `get_weather` | Get weather info for a city (supports Thai names for Thai cities) |

## Example Usage

**Get cities:**
```json
{"country": "thailand"}
// Returns: ["Bangkok", "Chiang Mai", "Phuket", ...]
```

**Get weather:**
```json
{"city": "Bangkok"}
// Returns: {"city": "Bangkok", "condition": "Sunny", "temperature": 28.5, "humidity": 65.2}
```

## Testing with HTTP File

You can test the MCP endpoints using the included [test/test.http](test/test.http) file.

### Prerequisites

Install the [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client) extension in VS Code.

### Run Tests

1. Start the server: `python main.py`
2. Open `test/test.http` in VS Code
3. Click "Send Request" above any request to execute it

### Available Tests

- **Initialize** - Start MCP session
- **List tools** - Discover available tools
- **get_cities** - Get cities for Thailand, USA
- **get_weather** - Get weather for cities (English and Thai names)