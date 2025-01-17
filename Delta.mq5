//+------------------------------------------------------------------+
//|                                                        Delta.mq5 |
//|                                           Copyright 2024, FaceND |
//|                                  https://github.com/FaceND/Delta |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, FaceND"
#property link      "https://github.com/FaceND/Delta"
#property indicator_chart_window
#property indicator_plots 0
#property strict

enum ENUM_STATUS
{
 ENABLE,   // Enable
 DISABLE   // Disable
};

enum ENUM_ALERT
{
 POPUP,   // Popup and Sound
 SOUND,   // Sound
 EMAIL,   // Email
 NOTI     // Notification
};

input group "SETTINGS"
input ENUM_STATUS           BidAsk_Status    = ENABLE;             // Show Bid & Ask
input ENUM_ALERT            AlertType        = POPUP;              // Alert type

input group "ALERT"
input ENUM_STATUS           Diverg_Status    = DISABLE;            // Delta divergence

input group "POSITION"
input ENUM_BASE_CORNER      CornerPosition   = CORNER_LEFT_UPPER;  // Position
input int                   X_Distance       = 10;        // X distance from the corner
input int                   Y_Distance       = 20;        // Y distance from the corner

input group "STYLE"
input color                 PosColor         = clrLimeGreen;       // Positive color
input color                 NegColor         = clrRed;             // Negative color
input color                 TextColor        = clrWhite;           // Text color
input int                   FontSize         = 10;                 // Font size

MqlTick ticks[];

string obj_delta_label   = "Delta";
string obj_delta_volume = "DeltaVolume";

string obj_bid_volume   = "BidVolume";
string obj_ask_volume   = "AskVolume";

long delta = 0;
long bid = 0;
long ask = 0;

long previous_count = 0;

bool is_previous_price_set = false;
double previous_price = 0.0;

bool diverg_alert = true;
int bars;

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
   CreateObject(obj_delta_label, obj_delta_label, TextColor);
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
   ObjectDelete(0, obj_delta_label);
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
   if(Diverg_Status == ENABLE)
     {
      //+------------------------------------------------------------+
      double open  = iOpen(_Symbol, _Period, 0);
      double close = iClose(_Symbol, _Period, 0);
      //+------------------------------------------------------------+

      bool isBullishCandle = (close > open);
      bool isBearishCandle = (close < open);

      if(diverg_alert)
        {
         if((isBullishCandle && delta < 0) || (isBearishCandle && delta > 0))
           {
            string alertType = isBullishCandle ? "Negative" : "Positive";
            string textAlert = alertType + " Delta divergence";
            if(!SendAlert(textAlert))
              {
               Alert("Failed to send alert via " + EnumToString(AlertType));
              }
            diverg_alert = false;
           }
        }
      else
        {
         if((isBullishCandle && delta > 0) || (isBearishCandle && delta < 0))
           {
            diverg_alert = true;
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Function to sends an alert based on the specified alert type     |
//+------------------------------------------------------------------+
bool SendAlert(const string text)
  {
   bool success = false;

   switch (AlertType)
     {
      case POPUP:
         Alert(text);
         success = true;
         break;

      case SOUND:
         PlaySound("alert.wav");
         Print("Alert: " + text);
         success = true;
         break;

      case EMAIL:
         success = SendMail("Delta (" + _Symbol + ") Alert", text);
         break;

      case NOTI:
         success = SendNotification(text);
         break;

      default:
         Print("Invalid AlertType: " + IntegerToString(AlertType));
         break;
     }
   return success;
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
//| Function to updates the delta data                               |
//+------------------------------------------------------------------+
void UpdateDelta()
  {
   ArrayFree(ticks);
   //+---------------------------------------------------------------+
   long count = CopyTicksRange(_Symbol, ticks, COPY_TICKS_TIME_MS, 
                  ulong(iTime(_Symbol, _Period, 0)) * 1000);
   //+---------------------------------------------------------------+
   if(IsNewBar())
     {
      ResetValues();
     }
   if(count > 0)
     {
      for(long i = previous_count; i < count; i++)
        {
         CalculateDelta(ticks[i].bid);
        }
      previous_count = count;
     }
   SetDeltaObject();
  }
//+------------------------------------------------------------------+
//| Function to calculate the delta, bid and ask                     |
//+------------------------------------------------------------------+ 
void CalculateDelta(const double current_price)
  {
   if(!is_previous_price_set)
     {
      previous_price = iClose(_Symbol, _Period, 1);
      is_previous_price_set = true;
     }
   //-- Bid [/]
   if(previous_price < current_price)
     {
      delta += 1;
      bid += 1;
     }
   //-- Ask [\]
   else if(previous_price > current_price)
     {
      delta -= 1;
      ask += 1;
     }
   previous_price = current_price;
  }
//+------------------------------------------------------------------+
//| Function to sets up the delta object                             |
//+------------------------------------------------------------------+
void SetDeltaObject()
  {
   //-- Positive delta
   if(delta > 0)
     {
      ResultColor = _PosColor;
     }
   //-- Negative delta
   else if(delta < 0)
     {
      ResultColor = _NegColor;
     }
   //-- Neutral delta
   else
     {
      ResultColor = TextColor;
     }

   //-- Delta (color) object
   ObjectSetInteger(0, obj_delta_volume, 
      OBJPROP_COLOR, ResultColor);
   //-- Delta (text) object
   ObjectSetString (0, obj_delta_volume, 
      OBJPROP_TEXT, "           " + FormatVolume(delta));

   if(BidAsk_Status == ENABLE)
     {
      //-- Bid object
      ObjectSetString(0, obj_bid_volume, OBJPROP_TEXT,
         TextToSpaces(ObjectGetString(0, obj_delta_volume, 
            OBJPROP_TEXT)) + "  " + FormatVolume(bid));

      //-- Ask object
      ObjectSetString(0, obj_ask_volume, OBJPROP_TEXT,
         TextToSpaces(ObjectGetString(0, obj_bid_volume,   
            OBJPROP_TEXT)) + "   " + FormatVolume(ask));
     }
  }
//+------------------------------------------------------------------+
//| Function to resets the values for a new bar                      |
//+------------------------------------------------------------------+  
void ResetValues()
  {
   delta = 0;
   ask = 0;
   bid = 0;

   previous_count = 0;
   is_previous_price_set = false;
  }
//+------------------------------------------------------------------+
//| Function to check for the creation of a new bar                  |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   int bar_now = Bars(_Symbol, _Period);
   if(bars != bar_now)
     {
      bars = bar_now;
      return(true);
     }
   return(false);
  }
//+------------------------------------------------------------------+
//| Function to format volume value                                  |
//+------------------------------------------------------------------+
string FormatVolume(const long volume)
  {
   string formattedVolume;
   if(volume >= 1000)
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
string TextToSpaces(const string text)
  {
   int length = StringLen(text) + (FontSize-1);
   string result = "";

   for(int i = 0; i < length; i++)
     {
      result += " ";
     }
   return result;
  }
//+------------------------------------------------------------------+