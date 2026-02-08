from typing import Any
import random

import httpx
import uvicorn
from mcp.server.fastmcp import FastMCP
from starlette.middleware.cors import CORSMiddleware

# Initialize FastMCP server
mcp = FastMCP("weather", stateless_http=True)

# Thai cities mapping (English <-> Thai)
THAI_CITIES = {
    "Bangkok": "กรุงเทพมหานคร",
    "Chiang Mai": "เชียงใหม่",
    "Phuket": "ภูเก็ต",
    "Pattaya": "พัทยา",
    "Khon Kaen": "ขอนแก่น",
    "Hat Yai": "หาดใหญ่",
    "Nakhon Ratchasima": "นครราชสีมา",
    "Chiang Rai": "เชียงราย",
    "Udon Thani": "อุดรธานี",
    "Krabi": "กระบี่",
}

# Reverse mapping (Thai -> English)
THAI_TO_ENGLISH = {v: k for k, v in THAI_CITIES.items()}

# Additional Thai name aliases -> canonical English name
THAI_ALIASES = {
    "กรุงเทพ": "Bangkok",
    "กรุงเทพฯ": "Bangkok",
}


@mcp.tool()
async def get_cities(country: str) -> str:
    """Get list of cities for a given country.

    Args:
        country: Country name (e.g., usa, canada, uk, australia, india, portugal, thailand)

    Returns:
        List of cities
    """
    cities_by_country = {
        "usa": ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix"],
        "canada": ["Toronto", "Vancouver", "Montreal", "Calgary", "Ottawa"],
        "uk": ["London", "Manchester", "Birmingham", "Leeds", "Glasgow"],
        "australia": ["Sydney", "Melbourne", "Brisbane", "Perth", "Adelaide"],
        "india": ["Mumbai", "Delhi", "Bangalore", "Hyderabad", "Chennai"],
        "portugal": ["Lisbon", "Porto", "Braga", "Faro", "Coimbra"],
        "thailand": list(THAI_CITIES.keys()),
    }

    country_lower = country.lower()
    # Also support Thai word for Thailand
    if country_lower in ["thailand", "ประเทศไทย", "ไทย"]:
        country_lower = "thailand"

    cities = cities_by_country.get(country_lower, [])

    return str(cities)


@mcp.tool()
async def get_weather(city: str) -> str:
    """Get weather information for a given city.

    Args:
        city: City name (supports both English and Thai for Thai cities)

    Returns:
        Weather information
    """
    # Check if it's a Thai city (either English or Thai name)
    english_name = None
    thai_name = None
    
    if city in THAI_CITIES:
        english_name = city
    elif city in THAI_TO_ENGLISH:
        english_name = THAI_TO_ENGLISH[city]
    elif city in THAI_ALIASES:
        english_name = THAI_ALIASES[city]
    
    weather_conditions = ["Sunny", "Cloudy", "Rainy", "Snowy", "Windy"]
    temperature = random.uniform(-10, 35)
    humidity = random.uniform(20, 100)
    
    weather_info = {
        "city": english_name,
        "condition": random.choice(weather_conditions),
        "temperature": round(temperature, 2),
        "humidity": round(humidity, 2),
    }
    
    return str(weather_info)


# Create ASGI app at module level for uvicorn
app = mcp.streamable_http_app()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["mcp-session-id"],
)


def main():
    uvicorn.run(app, host="0.0.0.0", port=8000)


if __name__ == "__main__":
    main()