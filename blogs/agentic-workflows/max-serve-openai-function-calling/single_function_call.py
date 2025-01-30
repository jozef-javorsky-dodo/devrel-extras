from openai import OpenAI


client = OpenAI(base_url="http://0.0.0.0:8000/v1", api_key="local")


def get_weather(city: str) -> str:
    """Mock weather function that returns a simple response."""
    return f"The weather in {city} is sunny with a temperature of 72°F"


TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get current weather and forecast data for a city",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {
                        "type": "string",
                        "description": "The city name to get weather for",
                    }
                },
                "required": ["city"],
            },
        },
    }
]


def main():
    user_message = "What's the weather like in San Francisco?"
    print(f"user_message: {user_message}")
    response = client.chat.completions.create(
        model="modularai/llama-3.1",
        messages=[{"role": "user", "content": user_message}],
        tools=TOOLS,
        tool_choice="auto",
    )
    output = response.choices[0].message
    print("Output:", output)
    print("Tool calls:", output.tool_calls)

    if output.tool_calls:
        for tool_call in output.tool_calls:
            if tool_call.function.name == "get_weather":
                city = eval(tool_call.function.arguments)["city"]
                weather_response = get_weather(city)
                print("\nWeather response:", weather_response)


if __name__ == "__main__":
    main()
