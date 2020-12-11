//+------------------------------------------------------------------+
//|                                         BBands_Mean_Reversal.mq4 |
//|                                               EA Name: KND-BB-MR |
//|                                                                  |
//|                      EA based on Bollinger Bands "mean reversal" |
//|                                          strategy along with RSI |
//|                                                                  |
//|                                                    Rahul Dhangar |
//|                                         https://rahuldhangar.com |
//+------------------------------------------------------------------+
#property copyright "EA - KND-BB-MR by Rahul Dhangar"
#property link      "https://rahuldhangar.com"
#property version   "1.00"
#property strict

#property show_inputs
#include <CustomFunctions01.mqh>

input int magicNum = 73;   // Magic Number
input double fixedLotSize = 0;   // Lot Size (0 to auto-calculate)
input double riskPerTrade = 0.02;   // Risk Per Trade (in %/100)
input int fixedSL = 0;
input int fixedTP = 0;

input int bbPeriod = 50;   // BB Period

input double bandStdEntry = 2;   // BB Std Dev for Entry
input double bandStdProfitExit = 1; // BB Std Dev for TP
input double bandStdLossExit = 6;   // BB Std Dev for SL

input int rsiPeriod = 14;  // RSI Period
input int rsiUpperLevel = 60; // RSI Overbought Level
input int rsiLowerLevel = 40; // RSI Oversold Level

int openOrderID;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("+-+-+ EA: KND-BB-MR Started +-+-+");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("+-+-+ EA: KND-BB-MR Stopped +-+-+");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   double rsiValue = iRSI(NULL, 0, rsiPeriod, PRICE_CLOSE, 0);
   double bbMid = iBands(NULL, 0, bbPeriod, bandStdEntry, 0, PRICE_CLOSE, 0, 0);
   
   double bbLowerEntry = iBands(NULL, 0, bbPeriod, bandStdEntry, 0, PRICE_CLOSE, MODE_LOWER, 0);
   double bbUpperEntry = iBands(NULL, 0, bbPeriod, bandStdEntry, 0, PRICE_CLOSE, MODE_UPPER, 0);
   
   double bbLowerProfitExit = iBands(NULL, 0, bbPeriod, bandStdProfitExit, 0, PRICE_CLOSE, MODE_LOWER, 0);
   double bbUpperProfitExit = iBands(NULL, 0, bbPeriod, bandStdProfitExit, 0, PRICE_CLOSE, MODE_UPPER, 0);
   
   double bbLowerLossExit = iBands(NULL, 0, bbPeriod, bandStdLossExit, 0, PRICE_CLOSE, MODE_LOWER, 0);
   double bbUpperLossExit = iBands(NULL, 0, bbPeriod, bandStdLossExit, 0, PRICE_CLOSE, MODE_UPPER, 0);
   
   if( !CheckOpenOrdersByMagicNum(magicNum)) // if no open order from this EA, try entering a new position
   {
      double lotSize;
      if(Ask < bbLowerEntry && Open[0] > bbLowerEntry && rsiValue < rsiLowerLevel)  // buying
      {
         Print("*** Price is below bbLower & rsiValue is below " + rsiLowerLevel + " , Sending BUY order");
         double stopLossPrice = NormalizeDouble(bbLowerLossExit, Digits);
         double takeProfitPrice = NormalizeDouble(bbUpperProfitExit, Digits);
         Print("*** Entry: " + Ask + " | SL: " + stopLossPrice + " | TP: " + takeProfitPrice);
         if(fixedLotSize != 0)
            lotSize = fixedLotSize;
         else
            lotSize = OptimalLotSize(riskPerTrade, Ask, stopLossPrice);
         openOrderID = OrderSend(NULL, OP_BUYLIMIT, lotSize, Ask, 10, stopLossPrice, takeProfitPrice, "BOUGHT. ", magicNum, 0, clrGreen);
         if(openOrderID < 0)
         {
            int lastErrorNum = GetLastError();
            Print("Order Rejected. Error: " + lastErrorNum);
            CheckOrderSendError(lastErrorNum);
         }
      }
      else if(Bid > bbUpperEntry && Open[0] < bbUpperEntry && rsiValue > rsiUpperLevel)   // shorting
      {
         Print("*** Price is above bbUpper & rsiValue is above " + rsiUpperLevel + " , Sending SELL order");
         double stopLossPrice = NormalizeDouble(bbUpperLossExit, Digits);
         double takeProfitPrice = NormalizeDouble(bbLowerProfitExit, Digits);
         Print("*** Entry: " + Bid + " | SL: " + stopLossPrice + " | TP: " + takeProfitPrice);
         if(fixedLotSize != 0)
            lotSize = fixedLotSize;
         else
            lotSize = OptimalLotSize(riskPerTrade, Bid, stopLossPrice);         
         openOrderID = OrderSend(NULL, OP_SELLLIMIT, lotSize, Bid, 10, stopLossPrice, takeProfitPrice, "SOLD. ", magicNum, 0, clrRed);
         if(openOrderID < 0)
         {
            int lastErrorNum = GetLastError();
            Print("Order Rejected. Error: " + lastErrorNum);
            CheckOrderSendError(lastErrorNum);
         }
      }
   }
   else  // you already have a position, update orders if needed
   {
      if(OrderSelect(openOrderID, SELECT_BY_TICKET) == true)
      {
         int orderType = OrderType();  // Long = 0, Short = 1
         double optimalTakeProfit;
         double optimalStopLoss;
         
         if(fixedTP != 0 && fixedSL != 0){
            return;
         }
         else
         {
            if(fixedTP == 0)
            {            
               if(orderType == 0)   // Long position
               {
                  optimalTakeProfit = NormalizeDouble(bbUpperProfitExit, Digits);
               }
               else  //Short position
               {
                  optimalTakeProfit = NormalizeDouble(bbLowerProfitExit, Digits);
               }
            }
            else
            {
               optimalTakeProfit = OrderTakeProfit();
            }
            
            if(fixedSL == 0)
            {            
               if(orderType == 0)   // Long position
               {
                  optimalStopLoss = OrderStopLoss() < NormalizeDouble(bbLowerLossExit, Digits) ? OrderStopLoss() : NormalizeDouble(bbLowerLossExit, Digits);
               }
               else  //Short position
               {
                  optimalStopLoss = OrderStopLoss() > NormalizeDouble(bbUpperLossExit, Digits) ? OrderStopLoss() : NormalizeDouble(bbUpperLossExit, Digits);
               }
            }
            else
            {
               optimalStopLoss = OrderStopLoss();
            }
            double TP = OrderTakeProfit();
            double TPdistance = MathAbs(TP - optimalTakeProfit);
            double minPips = GetPipValue() * 1; // 1 pip
            if(TP != optimalTakeProfit && TPdistance > minPips)
            {
               // Print("*** Modifying Order");
               bool Ans = OrderModify(openOrderID, OrderOpenPrice(), optimalStopLoss, optimalTakeProfit, 0, clrBlue);
               if(Ans == true)
               {
                  Print("*** Order Modified: ", openOrderID);
                  return;
               }
               else
               {
                  Print("Unable to modify order: ", openOrderID);
               }
            }
         }         
      }
   }
}
//+------------------------------------------------------------------+
