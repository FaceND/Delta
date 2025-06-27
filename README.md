# Delta
The Delta is a versatile tool designed for MetaTrader 5, providing traders with critical <br/> 
insights into market activity. It calculates and displays Delta, Bid, and Ask values for each candlestick, <br/> 
offering enhanced clarity for market trend analysis.


## Table of Contents
- [Features](#features)
- [Installation](#installation)
- [Inputs](#inputs)
- [Customization](#customization)
- [Usage](#usage)
- [Script Code](#script-code)
- [Contributing](#contributing)
- [License](#license)


## Features
- **Delta Calculation**
  <br/> Measures the net difference between buying and selling pressure.
- **Bid and Ask**
  <br/> Provides clear visibility into the current market dynamics.
- **Customizable Alerts**
  <br/>Supports multiple notification options for key Delta events
  - Pop-up notifications
  - Sound alerts
  - Email notifications
  - Push notifications


## Installation
1. Download the **Delta.mq5** file from this repository.
2. Open MetaTrader 5
   - Launch MetaTrader 5.
   - Go to `File` -> `Open Data Folder`.
3. Place the Script
   - Navigate to `MQL5` -> `Indicators`.
   - Copy the `Delta.mq5` file into the Experts folder.
4. Refresh MetaTrader 5
   - Restart MetaTrader 5 or right-click in the Navigator window and select Refresh.


## Inputs
### 🔹 HIGH & LOW Group
| Input                    | Description                                                           |
|--------------------------|-----------------------------------------------------------------------|
| `Range Period`           | Timeframe to use for Delta calculation                                |

### 🔹 OPTION Group
| Input                 | Description                                                         |
|--------------------------|------------------------------------------------------------------|
| `Show Bid & Ask`      | Enable/Disable showing Bid and Ask values                           |
| `Alert type`          | Type of alert to send (e.g., Popup, Email, Notification)            |
| `Alert sound`         | Line color for lowest low                                           |

### 🔹 ALERT Group
| Input                 | Description                                                       |
|-----------------------|-------------------------------------------------------------------|
| `Delta divergence`    | Enable/Disable alerting on Delta divergence                       |


### 🔹 POSITION Group
| Input                 | Description                                                    |
|-----------------------|----------------------------------------------------------------|
| `Position`            | Screen corner where the panel will appear                      |
| `X distance`          | Distance from the corner on the X-axis                         |
| `Y distance`          | Distance from the corner on the Y-axis                         |

### 🔹 STYLE Group
| Input                 | Description                                               | 
|-----------------------|-----------------------------------------------------------|
| `Positive color`      | Color used when Delta is positive                         |
| `Negative color`      | Color used when Delta is negative                         |
| `Y distance`          | Distance from the corner on the Y-axis                    |
| `Text color`          | Color for all text shown                                  |
| `Font size`           | Font size used in the display                             |

### 🔹 POSITION Group
| Input                 | Description                                            |
|-----------------------|--------------------------------------------------------|
| `Position`            | Screen corner where the panel will appear              |
| `X distance`          | Distance from the corner on the X-axis                 |
| `Y distance`          | Distance from the corner on the Y-axis                 |

### 🔹 SERVICE Group
| Input                 | Description                                         |
|-----------------------|-----------------------------------------------------|
| `Identifier`          | Unique identifier used for the indicator objects    |


## Customization
You can customize the name of the object by modifying the following text in the script.
```mql5
string obj_delta_label  = "Delta";
string obj_delta_volume = "DeltaVolume";

string obj_bid_volume   = "BidVolume";
string obj_ask_volume   = "AskVolume";
```


## Usage
1. Attach the Delta to a chart in MetaTrader 5.
2. Configure the input settings based on your trading preferences
   - Choose the time range period.
   - Enable or disable the Bid/Ask display.
   - Choose the alert type and enable divergence alerts.
   - Customize the position, colors, and font size of the indicator.
4. Monitor the Delta, Bid, and Ask values on the chart and receive alerts as needed.


## Script Code
Below is the MQL5 code used to create the "Delta" values
```mql5
//+------------------------------------------------------------------+
//|                                                        Delta.mq5 |
//|                                           Copyright 2024, FaceND |
//|                                  https://github.com/FaceND/Delta |
//+------------------------------------------------------------------+
#property copyright     "Copyright 2024, FaceND"
#property link          "https://github.com/FaceND/Delta"
#property version       "1.4"
#property description   "Delta indicator detects market pressure by comparing Ask and Bid changes."
#property description   "Increments Delta when price moves up (Bid),"
#property description   "decrements when price moves down (Ask)"
#property description   "using price difference logic."
#property strict
#property indicator_chart_window
#property indicator_plots 0

enum ENUM_STATUS
{
 ENABLE,   // Enable
 DISABLE   // Disable
};

enum ENUM_ALERT
{
 POPUP,    // Popup and Sound
 SOUND,    // Sound
 EMAIL,    // Email
 NOTI      // Notification
};

enum ENUM_SOUND
{
 ALERT,    // alert.wav
 ALERT2,   // alert2.wav
 EXPERT,   // expert.wav
 NEWS,     // news.wav
 REQUEST   // request.wav
};

input group "DATA"
input ENUM_TIMEFRAMES       RangePeriod      = PERIOD_CURRENT;     // Range Period

input group "OPTION"
input ENUM_STATUS           ShowBidAsk       = DISABLE;            // Show Bid & Ask
input ENUM_ALERT            AlertType        = POPUP;              // Alert type
input ENUM_SOUND            AlertSound       = ALERT;              // Alert sound

input group "ALERT"
input ENUM_STATUS           DivergStatus     = DISABLE;            // Delta divergence

input group "POSITION"
input ENUM_BASE_CORNER      CornerPosition   = CORNER_LEFT_UPPER;  // Position
input int                   X_Distance       = 10;        // X distance from the corner
input int                   Y_Distance       = 20;        // Y distance from the corner

input group "STYLE"
input color                 PosColor         = clrLimeGreen;       // Positive color
input color                 NegColor         = clrRed;             // Negative color
input color                 TextColor        = clrWhite;           // Text color
input int                   FontSize         = 10;                 // Font size

input group "SERVICE"
input string                ObjectId         = "Delta";            // Identifier

#define DELTA_LABEL   ObjectId
#define DELTA_VOLUME  ObjectId + "-DeltaVolume"

#define BID_VOLUME    ObjectId + "-BidVolume"
#define ASK_VOLUME    ObjectId + "-AskVolume"

MqlTick ticks[];

int delta = 0;
int bid = 0;
int ask = 0;

int negative_delta = 0;
int positive_delta = 0;

int previous_count = 0;
const int period_seconds = PeriodSeconds(RangePeriod);
double previous_price = iClose(_Symbol, RangePeriod, 1);

bool is_diverg_alert_set = true;

int bars;

color ResultColor, _PosColor, _NegColor;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   _PosColor = (PosColor==clrNONE) ? TextColor : PosColor;
   _NegColor = (NegColor==clrNONE) ? TextColor : NegColor;

   //-- Delta
   CreateObject(DELTA_LABEL, "Delta", TextColor);
   CreateObject(DELTA_VOLUME, NULL, TextColor);

   //-- Bid & Ask
   if(ShowBidAsk == ENABLE)
     {
      CreateObject(BID_VOLUME, NULL, _PosColor);
      CreateObject(ASK_VOLUME, NULL, _NegColor);
     }
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectDelete(0, DELTA_LABEL);
   ObjectDelete(0, DELTA_VOLUME);

   if(ShowBidAsk == ENABLE)
     {
      ObjectDelete(0, BID_VOLUME);
      ObjectDelete(0, ASK_VOLUME);
     }
   ChartRedraw();
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
   SetDelta();
   OnAlert();

   return rates_total;
  }
//+------------------------------------------------------------------+
//| Function to handle alert trigger                                 |
//+------------------------------------------------------------------+
void OnAlert()
  {
   //-- Delta Divergence Alert
   if(DivergStatus == ENABLE)
     {
      if(previous_count <= 0)
        {
         return;
        }

      //+------------------------------------------------------------+
      const double open = ticks[0].bid;
      const double close = ticks[previous_count-1].bid;
      //+------------------------------------------------------------+

      const bool isBullish = (close > open);
      const bool isBearish = (close < open);

      if(!isBullish && !isBearish)
        {  
         return;
        }
      if(is_diverg_alert_set)
        {
         //-- Negative delta divergence    Positive delta divergence
         //if( (isBullish && delta < 0) || (isBearish && delta > 0) )
         if( (isBullish && delta < negative_delta) || (isBearish && delta > positive_delta) )
           {
            string alertType = isBullish ? "Negative" : "Positive";
            string textAlert = "("+FormatVolume(delta)+ ") " + 
                                 alertType + " Delta divergence";
            if(!SendAlert(textAlert))
              {
               Alert("Failed to send alert via " + EnumToString(AlertType));
              }
            is_diverg_alert_set = false;
           }
        }
      else
        {
         if(delta < negative_delta)
           {
            negative_delta = delta;
           }
         else if(delta > positive_delta)
           {
            positive_delta = delta;
           }
         if((isBullish && delta > 0) || (isBearish && delta < 0))
           {
            is_diverg_alert_set = true;
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

   switch(AlertType)
     {
      case POPUP:
         Alert(text);
         success = true;
         break;

      case SOUND:
         PlaySound(EnumToString(AlertSound));
         Print("🔔 [" + _Symbol + "] Alert: " + text);
         success = true;
         break;

      case EMAIL:
         success = SendMail("[" + _Symbol + "] Delta Alert", text);
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
     }
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
//+------------------------------------------------------------------+
//| Function to updates the delta data                               |
//+------------------------------------------------------------------+
void UpdateDelta()
  {
   const datetime time = TimeCurrent();
   const datetime start_time = (datetime)(time - (time % period_seconds));
   const datetime end_time = start_time + period_seconds;

   //+---------------------------------------------------------------+
   const int count = CopyTicksRange(_Symbol, ticks, COPY_TICKS_INFO,
                        start_time * 1000, end_time * 1000);
   //+---------------------------------------------------------------+

   if(IsNewBar())
     {
      ResetValues();
     }
   if(count <= 0 || previous_count == count)
     {
      return;
     }
   for(int i = previous_count; i < count; i++)
     {
      CalculateDelta(ticks[i].bid);
     }
   previous_count = count;
  }
//+------------------------------------------------------------------+
//| Function to calculate the delta, bid and ask                     |
//+------------------------------------------------------------------+ 
void CalculateDelta(const double current_price)
  {
   //+---------------------------------------------------------------+
   const double price_diff = current_price - previous_price;
   //+---------------------------------------------------------------+

   //-- Bid [/]
   if(price_diff > _Point * 0.1)
     {
      delta++;
      bid++;
     }
   //-- Ask [\]
   else if(price_diff < _Point * 0.1)
     {
      delta--;
      ask++;
     }
   previous_price = current_price;
  }
//+------------------------------------------------------------------+
//| Function to sets up the delta object                             |
//+------------------------------------------------------------------+
void SetDelta()
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
   ObjectSetInteger(0, DELTA_VOLUME,
      OBJPROP_COLOR, ResultColor);
   //-- Delta (text) object
   ObjectSetString (0, DELTA_VOLUME,
      OBJPROP_TEXT, "           " + FormatVolume(delta));

   if(ShowBidAsk == ENABLE)
     {
      //-- Bid object
      ObjectSetString(0, BID_VOLUME, OBJPROP_TEXT,
         TextToSpaces(ObjectGetString(0, DELTA_VOLUME,
            OBJPROP_TEXT)) + "  " + FormatVolume(bid));

      //-- Ask object
      ObjectSetString(0, ASK_VOLUME, OBJPROP_TEXT,
         TextToSpaces(ObjectGetString(0, DELTA_VOLUME,   
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
   
   positive_delta = 20;
   negative_delta = -20;

   previous_count = 0;

   is_diverg_alert_set = true;
  }
//+------------------------------------------------------------------+
//| Function to check for the creation of a new bar                  |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   int bar_now = Bars(_Symbol, RangePeriod);
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
```


## Contributing
1. Fork the repository.
2. Create a new branch for your feature or fix.
3. Commit your changes with descriptive commit messages.
4. Push your branch to your forked repository.
4. Open a pull request to the main repository's main branch.
5. Please ensure your code follows the existing code style and includes comments where necessary.

Please ensure your code follows the existing code style and includes comments where necessary.


## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
