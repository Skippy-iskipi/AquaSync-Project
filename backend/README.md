# Fish Data Scraper Backend

This is the Python backend service for scraping fish data from FishBase and LiveAquaria websites.

## Setup

1. Make sure you have Python 3.11.6 installed
2. Create a virtual environment:
   ```bash
   python -m venv venv
   ```

3. Activate the virtual environment:
   - Windows:
     ```bash
     .\venv\Scripts\activate
     ```
   - Unix/MacOS:
     ```bash
     source venv/bin/activate
     ```

4. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Running the Server

1. Make sure your virtual environment is activated
2. Start the server:
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

## API Endpoints

- `GET /`: Check if the API is running
- `POST /scrape`: Start scraping fish data
  - Query Parameters:
    - `format`: Output format ('json' or 'csv')
- `GET /download/{filename}`: Download the scraped data file

## Features

- Asynchronous web scraping using aiohttp
- Rate limiting and retry mechanism
- Support for both JSON and CSV output formats
- Error handling and logging
- CORS support for Flutter frontend integration

## Data Structure

The scraper collects the following information for each fish:

- Common Name
- Scientific Name
- Size (in cm)
- Habitat Type
- Temperament
- Social Behavior 