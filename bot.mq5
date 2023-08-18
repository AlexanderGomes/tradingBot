#include <Trade/Trade.mqh>
CTrade trade;

enum TradeOptions {
    SELL,
    BUY,
    ALL
};

enum MyTimeframe {
    M1      = PERIOD_M1,
    M5      = PERIOD_M5,
    M15     = PERIOD_M15,
    M30     = PERIOD_M30,
    H1      = PERIOD_H1,
    H4      = PERIOD_H4,
    CURRENT = PERIOD_CURRENT
};

// User inputs
input MyTimeframe inputTimeframe = CURRENT;
input TradeOptions tradeChoices = ALL;
input double referenceLine1 = 0;
input double referenceLine2 = 0;
input int pipsOutsideNeutralZone = 0;
input int pipsAboveZeroZero = 0;
input int takeLevels = 1;
input double riskPercentage = 0;
input bool canBreakEven = false;
input double upperZone = 1000000;
input double lowerZone = -1;
input int allowedTakeProfits = 0;
input int allowedStopLoss = 0;

// Program inputs
double channelSizePoints = NormalizeDouble(MathAbs(referenceLine1 - referenceLine2) / _Point * _Point, _Digits);
double neutralZone = referenceLine2 + (referenceLine1 - referenceLine2) / 2;
double zeroZero = 0.0;

bool shouldChangeSL = false;
int positionType;
ulong orderTicket = 0;
double currentStopLoss;
bool priceChanged = false;

int wins = 0;
int losses = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
    ChartSetSymbolPeriod(0, _Symbol, (ENUM_TIMEFRAMES)inputTimeframe);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    ObjectDelete(0, "first line");
    ObjectDelete(0, "second line");
    ObjectDelete(0, "neutral line");
    ObjectDelete(0, "zero_zero");
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double prevPrice = 0;
bool priceChanged = false;

void OnTick() {
    double lastCandleClosePrice = iClose(_Symbol, inputTimeframe, 0);
    double currentPriceTrade = GetLastTradeValue();

    if (prevPrice != currentPriceTrade) {
        prevPrice = currentPriceTrade;
        priceChanged = true;
        UpdateWinsAndLosses();
    }

    if (!PositionSelectByTicket(orderTicket)) {
        orderTicket = 0;
    }

    bool isBuying = referenceLine1 > referenceLine2;
    double outsideNeutralZone = isBuying ? referenceLine2 - pipsOutsideNeutralZone * _Point : referenceLine2 + pipsOutsideNeutralZone * _Point;
    double nextReferenceLine = isBuying ? referenceLine1 + channelSizePoints : referenceLine1 - channelSizePoints;

    if (isBuying) {
        if (lastCandleClosePrice > referenceLine1) {
            bool canOpenBuyOrder = orderTicket <= 0 && (tradeChoices == BUY || tradeChoices == ALL) &&
                                    (lastCandleClosePrice > upperZone || lastCandleClosePrice < lowerZone || upperZone == 0) &&
                                    (wins < allowedTakeProfits || allowedTakeProfits == 0) &&
                                    (losses < allowedStopLoss || allowedStopLoss == 0);

            if (canOpenBuyOrder) {
                currentStopLoss = NormalizeDouble(outsideNeutralZone, _Digits);
                OpenOrder(currentStopLoss, isBuying);
            }

            referenceLine2 = referenceLine1;
            referenceLine1 = nextReferenceLine;
        }

        bool shouldInvertLinesBuy = lastCandleClosePrice < neutralZone;
        if (shouldInvertLinesBuy) {
            referenceLine1 = neutralZone;
        }

        bool shouldBreakEvenBuy = orderTicket > 0 && lastCandleClosePrice > zeroZero &&
                                  positionType == POSITION_TYPE_BUY && canBreakEven;

        if (shouldBreakEvenBuy) {
            if (!shouldChangeSL) {
                shouldChangeSL = true;
                ModifyPositionSLAndTP(orderTicket, isBuying);
            }
        } else {
            shouldChangeSL = false;
        }
    } else {
        if (lastCandleClosePrice < referenceLine1) {
            bool canOpenSellOrder = orderTicket <= 0 && (tradeChoices == SELL || tradeChoices == ALL) &&
                                    (lastCandleClosePrice < lowerZone || lastCandleClosePrice > upperZone || lowerZone == 0) &&
                                    (wins < allowedTakeProfits || allowedTakeProfits == 0) &&
                                    (losses < allowedStopLoss || allowedStopLoss == 0);

            if (canOpenSellOrder) {
                currentStopLoss = NormalizeDouble(outsideNeutralZone, _Digits);
                OpenOrder(currentStopLoss, isBuying);
            }

            referenceLine2 = referenceLine1;
            referenceLine1 = nextReferenceLine;
        }

        bool shouldInvertLinesSell = lastCandleClosePrice > neutralZone;
        if (shouldInvertLinesSell) {
            referenceLine1 = neutralZone;
        }

        bool shouldBreakEvenSell = orderTicket > 0 && lastCandleClosePrice < zeroZero &&
                                   positionType == POSITION_TYPE_SELL && canBreakEven;

        if (shouldBreakEvenSell) {
            if (!shouldChangeSL) {
                shouldChangeSL = true;
                ModifyPositionSLAndTP(orderTicket, isBuying);
            }
        } else {
            shouldChangeSL = false;
        }
    }

    DrawLines(referenceLine1, referenceLine2, neutralZone, zeroZero);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawLines(double value1, double value2, double value3, double zero) {
    if (ObjectGetDouble(0, "first line", OBJPROP_PRICE) != value1) {
        ObjectCreate(0, "first line", OBJ_HLINE, 0, 0, value1);
    }
    ObjectSetInteger(0, "first line", OBJPROP_COLOR, clrBlue);

    if (ObjectGetDouble(0, "second line", OBJPROP_PRICE) != value2) {
        ObjectCreate(0, "second line", OBJ_HLINE, 0, 0, value2);
    }
    ObjectSetInteger(0, "second line", OBJPROP_COLOR, clrBlue);

    if (ObjectGetDouble(0, "neutral line", OBJPROP_PRICE) != value3) {
        ObjectCreate(0, "neutral line", OBJ_HLINE, 0, 0, value3);
    }
    ObjectSetInteger(0, "neutral line", OBJPROP_COLOR, clrGold);

    if (ObjectGetDouble(0, "zero_zero", OBJPROP_PRICE) != zero) {
        ObjectCreate(0, "zero_zero", OBJ_HLINE, 0, 0, zero);
    }
    ObjectSetInteger(0, "zero_zero", OBJPROP_COLOR, clrAqua);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetLastTradeValue() {
    uint totalOrders = HistoryDealsTotal();
    HistorySelect(0, TimeCurrent());
    ulong ticketNumber = 0;
    double profit = 0;
    string symbol;

    for (uint i = 0; i < totalOrders; i++) {
        if ((ticketNumber = HistoryDealGetTicket(i)) > 0) {
            symbol = HistoryDealGetString(ticketNumber, DEAL_SYMBOL);

            if (symbol == _Symbol) {
                profit = HistoryDealGetDouble(ticketNumber, DEAL_PROFIT);
            }
        }
    }

    return profit;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateWinsAndLosses() {
    double profit = GetLastTradeValue();

    if (profit > 0 && priceChanged) {
        wins++;
    } else if (profit < 0 && priceChanged) {
        losses++;
    }

    priceChanged = false;
}

//+------------------------------------------------------------------+
