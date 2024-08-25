//+------------------------------------------------------------------+
//|                                                        Delta.mq5 |
//|                                           Copyright 2024, FaceND |
//|                                  https://github.com/FaceND/Delta |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, FaceND"
#property link      "https://github.com/FaceND/Delta"
#property strict
#property indicator_chart_window
#property indicator_plots 0

enum ENUM_STATUS
{
 ENABLE,       // Enable
 DISABLE       // Disable
};

input group "DATA"
input ENUM_TIMEFRAMES       PeriodType       = PERIOD_CURRENT;       // Period
input ENUM_STATUS           BidAsk_Status    = ENABLE;               // Bid & Ask

input group "ALERT"
input ENUM_STATUS           Diverg_Status    = ENABLE;               // Delta divergence

input group "POSITION"
input ENUM_BASE_CORNER      CornerPosition   = CORNER_LEFT_UPPER;    // Position
input int                   X_Distance       = 10;                   // X distance from the corner
input int                   Y_Distance       = 20;                   // Y distance from the corner

input group "STYLE"
input color                 PosColor         = clrLimeGreen;         // Positive color
input color                 NegColor         = clrRed;               // Negative color
input color                 TextColor        = clrWhite;             // Text color
input int                   FontSize         = 10;                   // Font size

MqlTick ticks[];

string obj_delta_name   = "Delta";
string obj_delta_volume = "DeltaVolume";

string obj_bid_volume   = "BidVolume";
string obj_ask_volume   = "AskVolume";

long delta = 0;
long bid = 0;
long ask = 0;

bool diverg_alert = true;

color ResultColor, _PosColor, _NegColor;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   _PosColor = (PosColor==clrNONE) ? TextColor : PosColor;
   _NegColor = (NegColor==clrNONE) ? TextColor : NegColor;

   diverg_alert = true;

   //-- Delta
   CreateObject(obj_delta_name, obj_delta_name, TextColor);
   CreateObject(obj_delta_volume, NULL, TextColor);

   //-- Bid & Ask
   if(BidAsk_Status == ENABLE)
     {
      CreateObject(obj_bid_volume, NULL, _PosColor);
      CreateObject(obj_ask_volume, NULL, _NegColor);
     }
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectDelete(0, obj_delta_name);
   ObjectDelete(0, obj_delta_volume);

   ObjectDelete(0, obj_bid_volume);
   ObjectDelete(0, obj_ask_volume);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int           rates_total,
                const int       prev_calculated,
                const datetime          &time[],
                const double            &open[],
                const double            &high[],
                const double             &low[],
                const double           &close[],
                const long       &tick_volume[],
                const long            &volume[],
                const int             &spread[])
  {
   UpdateDelta();
   onAlert();
   return rates_total;
  }
//+------------------------------------------------------------------+
//| Function to handle alert trigger                                 |
//+------------------------------------------------------------------+
void onAlert()
  {
   //-- Delta Divergence Alert
   if(delta == 0)
     {
      diverg_alert = true;
     }
   if(Diverg_Status == ENABLE && diverg_alert)
     {
      double open = iOpen(_Symbol, PeriodType, 0);
      double close = iClose(_Symbol, PeriodType, 0);
      if(close > open && delta < 0)
        {
         Alert("Negative Delta divergence");
         diverg_alert = false;
        }
      else if(close < open && delta > 0)
        {
         Alert("Positive Delta divergence");
         diverg_alert = false;
        }
     }
  }
//+------------------------------------------------------------------+
//| Custom indicator Construction object function                    |
//+------------------------------------------------------------------+
void CreateObject(const string          name, 
                  const string          text, 
                  const color      textColor) 
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER,  CornerPosition);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE,   X_Distance);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE,   Y_Distance);
      ObjectSetInteger(0, name, OBJPROP_COLOR,        textColor);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE,      FontSize);
      if(text == "" || text == NULL)
        {
         ObjectSetString(0, name, OBJPROP_TEXT, " ");
        }
      else
        {
         ObjectSetString(0, name, OBJPROP_TEXT, text);
        }
     }
  }
//+------------------------------------------------------------------+
//| Updates the data delta                                           |
//+------------------------------------------------------------------+
void UpdateDelta()
  {
   ArrayFree(ticks);

   long count = CopyTicksRange(_Symbol, ticks, COPY_TICKS_ALL, 
                              ulong(iTime(_Symbol, PeriodType, 0)) * 1000, 
                              ulong(TimeCurrent()) * 1000);

   double previous_price = NULL;

   delta = 0;
   ask = 0;
   bid = 0;

   if(count > 0)
     {
      for(int i = 0; i < count; i++)
        {
         if(previous_price == NULL)
           {
            previous_price = ticks[i].bid;
           }
         else
           {
            //-- Bid [/]
            if(previous_price < ticks[i].bid)
              {
               delta += 1;
               bid += 1;
              }
            //-- Ask [\]
            else if(previous_price > ticks[i].bid)
              {
               delta -= 1;
               ask += 1;
              }
            previous_price = ticks[i].bid;
           }
        }
     }
   SetDeltaObject();
  }
//+------------------------------------------------------------------+
//| Sets up the delta object                                         |
//+------------------------------------------------------------------+
void SetDeltaObject()
  {
   //-- Positive
   if(delta > 0)
     {
      ResultColor = _PosColor;
     }
   //-- Negative
   else if(delta < 0)
     {
      ResultColor = _NegColor;
     }
   //-- Neutral
   else
     {
      ResultColor = TextColor;
     }
   ObjectSetInteger(0, obj_delta_volume, OBJPROP_COLOR, ResultColor);
   ObjectSetString (0, obj_delta_volume, OBJPROP_TEXT, "          " + FormatVolume(delta));

   if(BidAsk_Status == ENABLE)
     {
      ObjectSetString(0, obj_bid_volume, OBJPROP_TEXT,TextToSpaces(ObjectGetString(0, obj_delta_volume,OBJPROP_TEXT)) + "      " + FormatVolume(bid));
      ObjectSetString(0, obj_ask_volume, OBJPROP_TEXT,TextToSpaces(ObjectGetString(0, obj_bid_volume,OBJPROP_TEXT)) + "        " + FormatVolume(ask));
     }
  }
//+------------------------------------------------------------------+
//| Function to format volume value                                  |
//+------------------------------------------------------------------+
string FormatVolume(long volume)
  {
   string formattedVolume;
   if(MathAbs(volume) >= 1000)
     {
      formattedVolume = DoubleToString(volume/1000.0, 3) + "K";
     }
   else
     {
      formattedVolume = IntegerToString(volume, 0);
     }
   return formattedVolume;
  }
//+------------------------------------------------------------------+
//| Converts a given text to spaces                                  |
//+------------------------------------------------------------------+
string TextToSpaces(string text)
  {
   int length = StringLen(text);
   string result = "";

   for(int i = 0; i < length; i++)
     {
      result += " ";
     }
   return result;
  }
//+------------------------------------------------------------------+