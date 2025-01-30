# Agentic Building Blocks: Creating AI Agents with MAX Serve and OpenAI Function Calling

Building intelligent agents that interact seamlessly with users requires structured and efficient mechanisms for executing actions.
OpenAI's function calling feature and Modular's [MAX Serve](https://docs.modular.com/max/serve) provide a powerful combination to enable dynamic and context-aware AI applications

In this blog, we will:

- Explain what LLM function calling is and why it's useful using MAX Serve and llama3-8B which we can run in CPU and GPU.
- Demonstrate how to use OpenAI's function calling to interact with external tools.
- Showcase how MAX Serve can facilitate local and cloud deployment of LLM-based applications.
- Walk through a working example that you can clone and run locally.

Note that this feature is available in [MAX nightly 25.1.0.dev2025012905](https://github.com/modular/max/commit/2f83e343a4d28a341570b2aab7131ff2da3e19d5) and the code is available in our [GitHub repository](https://github.com/modular/devrel-extras/tree/main/blogs/agentic-workflows/max-serve-openai-function-calling).

To proceed, please make sure to install magic` CLI

```bash
curl -ssL https://magic.modular.com/ | bash
```

Or update it via

```bash
magic self-update
```

## What is LLM function calling and why is it useful?

Large Language Models (LLMs) are typically used for text-based interactions. However, in real-world applications, they often need to interact with APIs, databases, or external tools to fetch real-time information. OpenAI's function calling enables an LLM to:

- Recognize when a function call is needed.
- Generate structured function parameters.
- Invoke functions dynamically to retrieve external data.

### Why use function calling?

Function calling allows LLMs to enhance their responses by:

- **Fetching real-time information** (e.g., weather data, stock prices, or news updates).
- **Interacting with databases and APIs** (e.g., retrieving user details or making transactions).
- **Improving accuracy and reliability** by reducing hallucinations (LLMs fabricating responses).
- **Automating API interactions** by directly invoking the necessary function instead of relying on unstructured text output.

## Implementing function calling with OpenAI

To illustrate function calling, let's start with a simple example where an AI retrieves the weather using a mock function.

### `single_function_call.py`

```python
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
                    "city": {"type": "string", "description": "The city name to get weather for"}
                },
                "required": ["city"],
            },
        },
    }
]

def main():
    user_message = "What's the weather like in San Francisco?"

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
```

Run the example via:

```bash
magic run single_function_call
```

Note that the very first compilation of the model can take a few minutes. The next invocations will be much faster.

### Understanding the function calling format

The function definition follows OpenAI's structured format for tool specifications:

```json
{
    "type": "function",
    "function": {
        "name": "get_weather",
        "description": "Get current weather and forecast data for a city",
        "parameters": {
            "type": "object",
            "properties": {
                "city": {"type": "string", "description": "The city name to get weather for"}
            },
            "required": ["city"]
        }
    }
}
```

Let's break down each component:

- `type`: Specifies this is a function tool (OpenAI supports different tool types)
- `function`: Contains the function's specification
  - `name`: The function identifier used by the LLM to call it
  - `description`: Helps the LLM understand when to use this function
  - `parameters`: JSON Schema defining the function's parameters
    - `type`: Defines this as an object containing parameters
    - `properties`: Lists all possible parameters and their types
    - `required`: Specifies which parameters must be provided

This schema enables the LLM to understand:

1. What the function does
2. When to use it
3. What parameters it needs
4. How to format the function call

### Why is this useful?

This script demonstrates how an AI model detects:

  1. when a function call is required,
  2. generates the necessary parameters, and
  3. retrieves information dynamically.

This automates API calls within conversational AI agents, allowing for structured responses instead of free-text generations.

## Expanding to multiple functions

For more complex applications, we can introduce multiple function calls. Below is an example that allows the LLM to fetch both weather and air quality data.

### `multi_function_calls.py`

Let's include another mock function as follows:

```python
from openai import OpenAI

client = OpenAI(base_url="http://0.0.0.0:8000/v1", api_key="local")

def get_weather(city: str) -> str:
    return f"The weather in {city} is sunny with a temperature of 72°F"

def get_air_quality(city: str) -> str:
    return f"The air quality in {city} is good with a PM2.5 of 10µg/m³"

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
    },
    {
        "type": "function",
        "function": {
            "name": "get_air_quality",
            "description": "Get air quality data for a city",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {
                        "type": "string",
                        "description": "The city name to get air quality for",
                    }
                },
                "required": ["city"],
                "additionalProperties": False,
            },
            "strict": True,
        },
    },
]
```

The LLM can now determine when to call `get_weather` or `get_air_quality` based on user input. This makes it possible to automate multiple API calls dynamically, allowing AI assistants to retrieve data from various sources.

Run the example via:

```bash
magic run muli_function_calls
```

## Deploying with MAX Serve

To better simulate the real use case, we use `app.py`, a FastAPI-based service that integrates function calling with a real API.

### Prerequisites

Before running the application, make sure you have a valid API key for weather data. To follow along, obtain
your free API key `WEATHERAPI_API_KEY` from [https://www.weatherapi.com/](https://www.weatherapi.com/) and include it in the `.env` file.

```txt
WEATHERAPI_API_KEY=your_api_key_here
```

### Weather app with function calling

Here is the code for the FastAPI weather app:

```python

class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    type: str
    message: str
    data: Optional[Dict[str, Any]] = None


def get_weather(city: str) -> Dict[str, Any]:
    """Get weather data for a city"""
    url = f"http://api.weatherapi.com/v1/current.json?key={WEATHER_API_KEY}&q={city}"
    response = requests.get(url)
    if response.status_code != 200:
        raise HTTPException(
            status_code=response.status_code, detail="Weather API error"
        )

    data = response.json()
    return {
        "location": data["location"]["name"],
        "temperature": data["current"]["temp_c"],
        "condition": data["current"]["condition"]["text"],
    }


def get_air_quality(city: str) -> Dict[str, Any]:
    """Get air quality data for a city"""
    url = f"http://api.weatherapi.com/v1/current.json?key={WEATHER_API_KEY}&q={city}&aqi=yes"
    response = requests.get(url)
    if response.status_code != 200:
        raise HTTPException(
            status_code=response.status_code, detail="Air quality API error"
        )

    data = response.json()
    aqi = data["current"].get("air_quality", {})
    return {
        "location": data["location"]["name"],
        "aqi": aqi.get("us-epa-index", 0),
        "pm2_5": aqi.get("pm2_5", 0),
    }


TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get current weather for a city",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {"type": "string", "description": "City name"},
                },
                "required": ["city"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_air_quality",
            "description": "Get air quality for a city",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {"type": "string", "description": "City name"},
                },
                "required": ["city"],
            },
        },
    },
]


@app.get("/api/health")
def health_check():
    return {"status": "healthy"}


@app.post("/api/chat", response_model=ChatResponse)
def chat(request: ChatRequest):
    try:
        response = client.chat.completions.create(
            model="modularai/llama-3.1",
            messages=[
                {
                    "role": "system",
                    "content": "You are a weather assistant. Use the available functions to get weather and air quality data.",
                },
                {"role": "user", "content": request.message},
            ],
            tools=TOOLS,
            tool_choice="auto",
        )

        message = response.choices[0].message

        if message.tool_calls:
            tool_call = message.tool_calls[0]
            function_name = tool_call.function.name
            function_args = eval(tool_call.function.arguments)

            if function_name == "get_weather":
                data = get_weather(function_args["city"])
                return ChatResponse(
                    type="weather", message="Here's the weather data", data=data
                )
            elif function_name == "get_air_quality":
                data = get_air_quality(function_args["city"])
                return ChatResponse(
                    type="air_quality", message="Here's the air quality data", data=data
                )
            else:
                raise HTTPException(status_code=400, detail="Unknown function call")

        return ChatResponse(type="chat", message=message.content)

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

We deploy it locally using:

```bash
magic run app
```

This will run MAX Serve on port `8000` and our FastAPI application on port `8001` which we can test with:

```bash
curl -X POST http://localhost:8001/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What is the weather in Toronto?"}'
```

the expected output is:

```json
{
  "type":"weather",
  "message":"Here's the weather data",
  "data": {
      "location":"Toronto",
      "temperature":-3.0,
      "condition":"Partly cloudy"
  }
}
```

and as another example testing the air quality function calling

```bash
curl -X POST http://localhost:8001/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What is the air quality in Vancouver?"}'
```

the expected output is:

```json
{
  "type": "air_quality",
  "message": "Here's the air quality data",
  "data": {
    "location": "Vancouver",
    "aqi": 1,
    "pm2_5": 3.515
  }
}
```

### What the app automates

The app automates the following tasks:

- Interpreting user queries.
- Identifying which external API (weather or air quality) to call.
- Fetching real-time data from WeatherAPI.
- Structuring the response back to the user in a formatted way.

## Conclusion

OpenAI's function calling and MAX Serve together provide an efficient way to build intelligent, interactive agents. By leveraging these tools, developers can:

- Dynamically invoke APIs.
- Improve LLM responses with real-world data.
- Deploy scalable AI-powered applications.

## What's next?

Now that you've implemented function calling with MAX Serve, you can explore more advanced features and join our developer community. Here are some resources to help you continue your journey:

- [Get started with MAX](https://docs.modular.com/max/get-started)
- Explore [MAX Serve](https://docs.modular.com/max/serve) and [Magic tutorial](https://docs.modular.com/max/tutorials/magic).
- Join our [Discord](https://discord.gg/modular) and our [Modular forum](https://forum.modular.com/)
