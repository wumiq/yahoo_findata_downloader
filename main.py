import asyncio
from fastapi import FastAPI, HTTPException
from yfin_data import download_prefix, pull_changes, push_changes, record_summary

app = FastAPI()

@app.get("/")
async def root():
    return {"message": "Hello World"}


@app.get("/records")
async def stat():
    return await record_summary()

@app.patch("/pull/{prefix}")
async def pull_by_prefix(prefix):
    """Pull historical data for stocks start with $prefix."""
    if prefix not in set('ABCDEFGHIJKLMNOPQRSTUVWXYZ'):
        raise HTTPException(
            status_code=400,
             detail=f"prefix must be an English Capital letter, '{prefix}' is given")
    await asyncio.get_event_loop().run_in_executor(None, pull_changes)
    await download_prefix(prefix)
    await asyncio.get_event_loop().run_in_executor(None, push_changes)


import uvicorn

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000)
