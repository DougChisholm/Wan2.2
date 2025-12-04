# Wan 2.2 API - Usage Examples

This document provides detailed examples of how to use the Wan 2.2 Video Generation API.

## Prerequisites

- API endpoint URL (obtained after deployment)
- `curl` or any HTTP client
- For image-to-video: an image file

## Basic Usage

### 1. Health Check

```bash
curl https://your-api-url.azurecontainerapps.io/health
```

Expected response:
```json
{
  "status": "healthy"
}
```

### 2. Get API Information

```bash
curl https://your-api-url.azurecontainerapps.io/
```

Expected response:
```json
{
  "status": "healthy",
  "message": "Wan 2.2 Video Generation API",
  "model_type": "ti2v-5B",
  "available_tasks": ["t2v-A14B", "i2v-A14B", "ti2v-5B", "s2v-14B", "animate-14B"]
}
```

### 3. List Available Tasks

```bash
curl https://your-api-url.azurecontainerapps.io/tasks
```

Expected response:
```json
{
  "available_tasks": ["t2v-A14B", "i2v-A14B", "ti2v-5B", "s2v-14B", "animate-14B"],
  "current_task": "ti2v-5B"
}
```

### 4. List Supported Sizes for a Task

```bash
curl https://your-api-url.azurecontainerapps.io/sizes/ti2v-5B
```

Expected response:
```json
{
  "task": "ti2v-5B",
  "supported_sizes": ["1280*704", "704*1280"]
}
```

## Video Generation Examples

### Text-to-Video Generation

Generate a video from text using the TI2V-5B model:

```bash
curl -X POST "https://your-api-url.azurecontainerapps.io/generate" \
  -F "prompt=Two anthropomorphic cats in comfy boxing gear and bright gloves fight intensely on a spotlighted stage" \
  -F "task=ti2v-5B" \
  -F "size=1280*704" \
  -F "frame_num=81" \
  -F "seed=42" \
  -o boxing_cats.mp4
```

### Image-to-Video Generation

Generate a video from an image and text prompt:

```bash
curl -X POST "https://your-api-url.azurecontainerapps.io/generate" \
  -F "prompt=Summer beach vacation style, a white cat wearing sunglasses sits on a surfboard. The fluffy-furred feline gazes directly at the camera with a relaxed expression." \
  -F "image=@/path/to/cat_image.jpg" \
  -F "task=ti2v-5B" \
  -F "size=1280*704" \
  -o beach_cat.mp4
```

### High-Quality Text-to-Video (T2V-A14B)

For higher quality (requires more resources):

```bash
curl -X POST "https://your-api-url.azurecontainerapps.io/generate" \
  -F "prompt=A serene mountain landscape at sunset with flowing clouds" \
  -F "task=t2v-A14B" \
  -F "size=1280*720" \
  -F "sample_steps=20" \
  -o mountain_sunset.mp4
```

### High-Quality Image-to-Video (I2V-A14B)

```bash
curl -X POST "https://your-api-url.azurecontainerapps.io/generate" \
  -F "prompt=The person in the image turns their head and smiles at the camera" \
  -F "image=@/path/to/portrait.jpg" \
  -F "task=i2v-A14B" \
  -F "size=720*1280" \
  -o portrait_smile.mp4
```

## Advanced Options

### Custom Sampling Parameters

Control the generation process with advanced parameters:

```bash
curl -X POST "https://your-api-url.azurecontainerapps.io/generate" \
  -F "prompt=A futuristic city with flying cars" \
  -F "task=ti2v-5B" \
  -F "size=1280*704" \
  -F "frame_num=121" \
  -F "seed=12345" \
  -F "sample_steps=30" \
  -F "guide_scale=7.5" \
  -o futuristic_city.mp4
```

**Parameters:**
- `frame_num`: Number of frames (must be 4n+1, e.g., 81, 121, 161)
- `seed`: Random seed for reproducibility (-1 for random)
- `sample_steps`: More steps = higher quality but slower
- `guide_scale`: Classifier-free guidance scale (higher = more prompt adherence)

### Portrait Orientation

Generate vertical videos:

```bash
curl -X POST "https://your-api-url.azurecontainerapps.io/generate" \
  -F "prompt=A tall waterfall cascading down a cliff" \
  -F "task=ti2v-5B" \
  -F "size=704*1280" \
  -o waterfall.mp4
```

## Python Examples

### Using Requests Library

```python
import requests

# Text-to-Video
response = requests.post(
    "https://your-api-url.azurecontainerapps.io/generate",
    data={
        "prompt": "A cat playing with a ball of yarn",
        "task": "ti2v-5B",
        "size": "1280*704",
        "seed": 42
    }
)

with open("output.mp4", "wb") as f:
    f.write(response.content)
```

### Image-to-Video with Python

```python
import requests

# Image-to-Video
with open("input_image.jpg", "rb") as img_file:
    files = {"image": img_file}
    data = {
        "prompt": "The scene comes to life with gentle movement",
        "task": "ti2v-5B",
        "size": "1280*704"
    }
    
    response = requests.post(
        "https://your-api-url.azurecontainerapps.io/generate",
        data=data,
        files=files
    )

with open("output.mp4", "wb") as f:
    f.write(response.content)
```

### Async Python Example

```python
import aiohttp
import asyncio

async def generate_video(prompt, output_file):
    async with aiohttp.ClientSession() as session:
        data = aiohttp.FormData()
        data.add_field("prompt", prompt)
        data.add_field("task", "ti2v-5B")
        data.add_field("size", "1280*704")
        
        async with session.post(
            "https://your-api-url.azurecontainerapps.io/generate",
            data=data
        ) as response:
            with open(output_file, "wb") as f:
                f.write(await response.read())

# Run async
asyncio.run(generate_video("A sunset over the ocean", "sunset.mp4"))
```

## JavaScript/Node.js Examples

### Using Fetch API

```javascript
const FormData = require('form-data');
const fetch = require('node-fetch');
const fs = require('fs');

async function generateVideo(prompt, outputFile) {
  const formData = new FormData();
  formData.append('prompt', prompt);
  formData.append('task', 'ti2v-5B');
  formData.append('size', '1280*704');
  
  const response = await fetch('https://your-api-url.azurecontainerapps.io/generate', {
    method: 'POST',
    body: formData
  });
  
  const buffer = await response.buffer();
  fs.writeFileSync(outputFile, buffer);
}

generateVideo('A bird flying in the sky', 'bird.mp4');
```

### With Image Upload

```javascript
const FormData = require('form-data');
const fetch = require('node-fetch');
const fs = require('fs');

async function generateVideoFromImage(imagePath, prompt, outputFile) {
  const formData = new FormData();
  formData.append('prompt', prompt);
  formData.append('task', 'ti2v-5B');
  formData.append('size', '1280*704');
  formData.append('image', fs.createReadStream(imagePath));
  
  const response = await fetch('https://your-api-url.azurecontainerapps.io/generate', {
    method: 'POST',
    body: formData
  });
  
  const buffer = await response.buffer();
  fs.writeFileSync(outputFile, buffer);
}

generateVideoFromImage('input.jpg', 'The person waves hello', 'wave.mp4');
```

## Response Codes

- `200 OK`: Video generated successfully, returns MP4 file
- `400 Bad Request`: Invalid parameters or missing required fields
- `500 Internal Server Error`: Generation failed, check logs

## Error Handling

### Example Error Response

```json
{
  "detail": "Video generation failed: CUDA out of memory"
}
```

### Handling Errors in Python

```python
import requests

response = requests.post(
    "https://your-api-url.azurecontainerapps.io/generate",
    data={
        "prompt": "A test prompt",
        "task": "ti2v-5B"
    }
)

if response.status_code == 200:
    with open("output.mp4", "wb") as f:
        f.write(response.content)
    print("Video generated successfully!")
else:
    print(f"Error {response.status_code}: {response.json()['detail']}")
```

## Performance Tips

1. **Use TI2V-5B for fastest results** (default model)
2. **Reduce frame_num** for quicker generation (default: 81)
3. **Lower sample_steps** for faster but lower quality (default: 20)
4. **Use smaller resolutions** when possible
5. **Enable caching** by using the same seed for reproducible results

## Model Comparison

| Model | Quality | Speed | Resolution | Use Case |
|-------|---------|-------|------------|----------|
| ti2v-5B | Good | Fast | 720P | Production, quick generation |
| t2v-A14B | Excellent | Slow | 480P/720P | High-quality text-to-video |
| i2v-A14B | Excellent | Slow | 480P/720P | High-quality image-to-video |

## Rate Limiting

The API is configured to handle up to 10 concurrent requests per instance. For production use, consider:
- Implementing client-side rate limiting
- Queueing requests
- Using async/await patterns

## Best Practices

1. **Provide detailed prompts** for better results
2. **Use appropriate resolutions** for your use case
3. **Set a seed** for reproducible results
4. **Monitor API health** before submitting batch jobs
5. **Handle errors gracefully** with retries
6. **Cache results** when possible to save costs

## Support

For issues or questions:
- Check [DEPLOYMENT.md](DEPLOYMENT.md) for infrastructure issues
- Review [README.md](README.md) for model-specific questions
- Check container logs for debugging

## Example Prompts

### Good Prompts (Detailed)

✓ "A serene sunset over a calm ocean, with gentle waves lapping at a sandy beach. Warm orange and pink hues fill the sky, with a few seagulls flying in the distance. The camera slowly pans from left to right."

✓ "A futuristic city at night with neon lights, flying cars moving through the air, and holographic advertisements on tall buildings. Rain falls creating reflections on the wet streets below."

### Less Effective Prompts (Too Generic)

✗ "sunset"
✗ "city at night"
✗ "a person walking"

## Troubleshooting

### "CUDA out of memory"
- Try using ti2v-5B instead of A14B models
- Reduce frame_num
- Check if other requests are running

### "Generation timeout"
- Increase timeout in your HTTP client
- Consider reducing sample_steps or frame_num

### "Invalid size"
- Check supported sizes for your chosen task
- Use GET /sizes/{task} to see valid options

## Additional Resources

- [Wan 2.2 Project Page](https://wan.video)
- [Wan 2.2 Paper](https://arxiv.org/abs/2503.20314)
- [GitHub Repository](https://github.com/Wan-Video/Wan2.2)
