# Sierra Chart AI Trading Bot — Code Review

## Key issues found

1. **`finalScore` can never reach entry thresholds (`> 2.5` / `< -2.5`) with current weighting.**
   - `orderflow.score` ranges from `0` to `4` and contributes at most `1.4` (`4 * 0.35`).
   - `structure` is in `{-1, 0, 1}` and contributes in `[-0.25, 0.25]`.
   - `liquidity` is in `{-1, 0, 1}` and contributes in `[-0.2, 0.2]`.
   - So `finalScore` is bounded approximately to `[-0.45, 1.85]`, making both trade conditions unreachable.

2. **Sell-side order flow is never scored.**
   - `AnalyzeOrderFlow` only adds score when delta and imbalance are positive.
   - There is no mirrored bearish scoring for negative delta / inverse imbalance.

3. **`abs` used with `float` is risky / ambiguous in C++.**
   - Prefer `std::fabs` from `<cmath>` for floating-point distances.

4. **Potential issue if previous day high/low APIs are unavailable in the exact build.**
   - Depending on Sierra Chart version, methods like `GetPreviousDayHigh()` / `GetPreviousDayLow()` can differ.
   - Verify the exact ACSIL API names against your installed header/docs.

5. **Order object is not explicitly initialized.**
   - Use value initialization (`s_SCNewOrder order{};`) to avoid stale fields.

6. **No position/execution-state guard before sending entries.**
   - Without checks, signals can repeatedly fire and stack market orders.
   - Consider `sc.GetTradePosition(...)` and only enter when flat (or controlled scaling logic).

## Suggested corrected logic (conceptual)

```cpp
#include "sierrachart.h"
#include <cmath>

SCDLLName("AI Trading Bot")

float DELTA_THRESHOLD = 800;
float IMBALANCE_RATIO = 3.0f;

float MAX_DAILY_LOSS = 1000;
int MAX_TRADES_PER_DAY = 5;

struct SignalData
{
    float delta;
    float imbalance;
    float score; // now signed, roughly in [-4, +4]
};

SignalData AnalyzeOrderFlow(SCStudyInterfaceRef sc)
{
    SignalData signal{};

    const float askVol = sc.AskVolume[sc.Index];
    const float bidVol = sc.BidVolume[sc.Index];

    signal.delta = askVol - bidVol;
    signal.imbalance = (bidVol > 0.0f) ? (askVol / bidVol) : 0.0f;

    // Bullish scoring
    if (signal.delta > DELTA_THRESHOLD)
        signal.score += 2.0f;
    if (signal.imbalance > IMBALANCE_RATIO)
        signal.score += 2.0f;

    // Bearish scoring (mirrored)
    if (signal.delta < -DELTA_THRESHOLD)
        signal.score -= 2.0f;

    if (askVol > 0.0f)
    {
        const float invImbalance = bidVol / askVol;
        if (invImbalance > IMBALANCE_RATIO)
            signal.score -= 2.0f;
    }

    return signal;
}

float DetectMarketStructure(SCStudyInterfaceRef sc)
{
    const float vwap = sc.VWAP[sc.Index];
    const float price = sc.Close[sc.Index];

    if (price > vwap) return 1.0f;
    if (price < vwap) return -1.0f;
    return 0.0f;
}

float DetectLiquidity(SCStudyInterfaceRef sc)
{
    const float prevHigh = sc.GetPreviousDayHigh();
    const float prevLow = sc.GetPreviousDayLow();
    const float price = sc.Close[sc.Index];

    if (std::fabs(price - prevHigh) < 5.0f) return 1.0f;
    if (std::fabs(price - prevLow) < 5.0f) return -1.0f;
    return 0.0f;
}

bool RiskCheck(SCStudyInterfaceRef sc)
{
    if (sc.TradeStatisticsForSymbol.TradesToday >= MAX_TRADES_PER_DAY)
        return false;

    if (sc.TradeStatisticsForSymbol.DailyNetProfitLoss <= -MAX_DAILY_LOSS)
        return false;

    return true;
}

SCSFExport scsf_AITradingBot(SCStudyInterfaceRef sc)
{
    if (sc.SetDefaults)
    {
        sc.GraphName = "AI Trading Bot";
        sc.AutoLoop = 1;
        sc.FreeDLL = 0;
        return;
    }

    if (!RiskCheck(sc))
        return;

    SignalData orderflow = AnalyzeOrderFlow(sc);
    const float structure = DetectMarketStructure(sc);
    const float liquidity = DetectLiquidity(sc);

    // Rebalanced to preserve directional signal and a practical threshold
    const float finalScore =
        orderflow.score * 0.60f +
        structure * 0.25f +
        liquidity * 0.15f;

    // Optional: add flat-position check before entries in live trading.

    if (finalScore >= 1.25f)
    {
        sc.SetAlert(1, "Bullish Signal");

        s_SCNewOrder order{};
        order.OrderQuantity = 1;
        order.OrderType = SCT_ORDERTYPE_MARKET;

        sc.BuyEntry(order);
    }
    else if (finalScore <= -1.25f)
    {
        sc.SetAlert(2, "Bearish Signal");

        s_SCNewOrder order{};
        order.OrderQuantity = 1;
        order.OrderType = SCT_ORDERTYPE_MARKET;

        sc.SellEntry(order);
    }
}
```

## Quick verdict

The current code compiles in spirit but has **core logic flaws** that likely prevent live signal generation and one-sidedly biases the model long. The biggest blocker is unreachable trade thresholds.
