import asyncio
import contextlib
import json
import os
import subprocess
import typing as t
from datetime import datetime

import pandas as pd
import structlog
import yfinance as yf
from dateutil import tz

DEFAULT_DATA_FOLDER="tmp/repo"
RECORDS_FILE="records.csv"
SLEEP_SECS_BET_TICKERS=1

GH_TOKEN = os.environ.get("GH_TOKEN")

logger = structlog.get_logger(__name__)


def download_ticker(ticker: str, records: pd.DataFrame, data_folder=DEFAULT_DATA_FOLDER):
    """Download data to tmp/repo/A/AAPL.csv and return download data, also update records in-place."""
    log = logger.new(ticker=ticker)
    if records is None or not ticker:
        log.warning(f"Ticker and records must not be null, given ticker: {ticker}")
        return
    matched = records[records['Symbol'] == ticker]
    if matched.empty:
        log.warning(f"{ticker}: Symbol does not exist in our records")
        return
    ix = matched.index.tolist()[0]
    with open(os.devnull, 'w') as devnull:
        with contextlib.redirect_stdout(devnull):
                data: pd.DataFrame = yf.download(ticker, period='max')
                # update UpdatedAt before all returns
                records.loc[ix, 'UpdatedAt'] = datetime.now(tz=tz.UTC).timestamp()
                if data.empty:
                    logger.info(f"{ticker}: No data found, symbol may be delisted")
                    return
                last_eod = data.iloc[-1].name.strftime('%F')
                if len(data.index) == 0:
                    log.warning(f"Failed to download {ticker}")
                    return
                data_parent = os.path.join(data_folder, ticker[0])
                os.makedirs(data_parent, exist_ok=True)
                data_path = os.path.join(data_parent, f"{ticker}.csv")
                data.to_csv(data_path)
                log.info(f"Data download for {ticker} and saved to {data_path}")
                records.loc[ix, 'ToDate'] = last_eod
                return data


def read_records(data_folder=DEFAULT_DATA_FOLDER) -> pd.DataFrame:
    """
    Read records, useful columns are

    Symbol                                   AAPL
    Security Name       Apple Inc. - Common Stock
    Listing Exchange                            Q
    Market Category                             Q
    ETF                                         N
    CQS Symbol                                NaN
    NASDAQ Symbol                            AAPL
    NextShares                               MOCK
    Symbol
    """
    records_csv = os.path.join(data_folder, RECORDS_FILE)
    df_records: pd.DataFrame = pd.read_csv(records_csv, sep='|')
    logger.info(f"Read {len(df_records)} records")
    return df_records

def write_records(records: pd.DataFrame, data_folder=DEFAULT_DATA_FOLDER):
    if records is None or records.empty:
        logger.warning("Invalid records to write")
        return
    records_csv = os.path.join(data_folder, RECORDS_FILE)
    records.to_csv(records_csv, sep='|')
    logger.info("Updated records to {records_csv}")


def init_records() -> pd.DataFrame:
    raw = pd.read_csv("http://www.nasdaqtrader.com/dynamic/SymDir/nasdaqtraded.txt", sep='|')
    records = raw[raw['Test Issue'] == 'N']
    records.drop('Test Issue', axis=1)
    records.drop('Financial Status', axis=1)
    records.drop('NextShares', axis=1)
    logger.info(f"Downloaded {len(records)} tickers")
    records['ToDate'] = '-'
    records['UpdatedAt'] = 0
    write_records(records)
    return records


def main1():
    """r0, r1, aapl 1 main1"""
    records_0 = init_records()
    aapl = download_ticker('AAPL', records_0)
    write_records(records_0)
    records_1 = read_records()
    return (records_0, records_1, aapl)


def push_changes():
    """Call shell script to push"""


async def download_n(n: int = 100):
    records = read_records()
    loop = asyncio.get_event_loop()
    for _, r in records.sort_values(by='UpdatedAt').head(n).iterrows():
        await loop.run_in_executor(None, download_ticker, r['Symbol'], records)
        await asyncio.sleep(SLEEP_SECS_BET_TICKERS)
    write_records(records)


async def download_prefix(s: str):
    records = read_records()
    rsub = records[records['Symbol'].str.startswith(s)]
    loop = asyncio.get_event_loop()
    for _, r in rsub.sort_values(by='UpdatedAt').iterrows():
        await loop.run_in_executor(None, download_ticker, r['Symbol'], records)
        await asyncio.sleep(SLEEP_SECS_BET_TICKERS)
    write_records(records)

async def record_summary() -> t.Dict[str, str]:
    """Return r.Symbol: r.ToDate dict."""
    recs = read_records()
    return {r['Symbol']: r['ToDate'] for _, r in recs.iterrows()}


UPLOAD_CMDS = f"./repo_ops.sh -u -f {DEFAULT_DATA_FOLDER}".split()
DOWNLOAD_CMDS = f"./repo_ops.sh -d -f {DEFAULT_DATA_FOLDER}".split()

def push_changes():
    ret: subprocess.CompletedProcess = subprocess.run(
        'bash repo_ops.sh -u -f tmp/repo',
        check=True,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    logger.warning(ret.stderr)
    logger.info(ret.stdout)


def pull_changes():
    ret: subprocess.CompletedProcess = subprocess.run(
        'bash repo_ops.sh -d -f tmp/repo', 
        check=True,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    logger.warning(ret.stderr)
    logger.info(ret.stdout)
