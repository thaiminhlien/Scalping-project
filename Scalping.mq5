//+------------------------------------------------------------------+
//|                                                     Scalping.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include  <Trade/Trade.mqh>
CTrade  trade;
#include <Trade\PositionInfo.mqh>
CPositionInfo m_position;
#include <Arrays\List.mqh>



enum ModeTrade
  {
   LanChamDauTien=1,// chỉ chạm 1 lần đầu tiên
   ChamTrongMotCayNen=2, // chạm liên tục trong 1 cây nến
   ChamLienTuc=3 // chạm liên tục trong X cây nến
  };

input ModeTrade modeTrade = 1;
input int SoCayNenToiDaChamLienTuc = 2; //số cây nến tối đa cho phép chạm khi ModeTrade = 3

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input int DoCaoCuaThanhNen = 175;// độ cao của thanh nến sẽ vào lệnh (Points)
input double StopLoss = 30;//StopLoss in Points
input double TrailingStop = 100; //TralStart in points
input double TrailingStep = 50;//TralStep in points

input int ChieuSau = 20;//khoảng cách giá đặt và giá hiện tại
input int MaxSpreads = 15;//spreads tối đa
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
string name_KhangCu="";
string name_HoTro="";

double price_KhangCu = -1;
double price_HoTro = -1;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   if(price_KhangCu > -1)
     {
      if(getAsk()>= price_KhangCu)
        {
         //mở lệnh sellStop khi giá chạm kháng cự
         //đồng thời reset giá, không cho vào lệnh lần 2
         OpenStopOrder(ORDER_TYPE_SELL_STOP);
         price_KhangCu= -1;
         name_KhangCu="";
        }
     }
   if(price_HoTro > -1)
     {
      if(getBid()<= price_HoTro)
        {
         //mở lệnh buyStop khi giá chạm hỗ trợ
         //đồng thời reset giá, không cho vào lệnh lần 2
         OpenStopOrder(ORDER_TYPE_BUY_STOP);
         price_HoTro = -1;
         name_HoTro ="";
        }
     }

   int obj_total=ObjectsTotal(0);
   if(obj_total > 0)
      for(int i = 0; i < obj_total; i++)
        {
         string name = ObjectName(0,i);
         int match = StringFind(name,"Horizontal Line",0);
         if(match > -1)
           {
            ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
            ObjectSetInteger(0,name,OBJPROP_COLOR, clrLime);

            double price = ObjectGetDouble(0, name,OBJPROP_PRICE);
            string type ="";
            if(price > getAsk())
              {
               type = "Resistance";
               price_KhangCu= price;
               name_KhangCu = name;
              }
            else
               if(price < getBid())
                 {
                  type = "Support";
                  price_HoTro= price;
                  name_HoTro = name;
                 }
           }
        }
   string comment ="";
   if(price_HoTro > -1)
     {
      comment+="type=HoTro\nprice="+DoubleToString(price_HoTro,Digits())+"\n\n" ;
     }
   if(price_KhangCu > -1)
     {
      comment+="type=KhangCu\nprice="+DoubleToString(price_KhangCu,Digits())+"\n\n" ;
     }
   Comment(comment);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DisableHorizontalLine(string name)
  {
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DASH);
   ObjectSetInteger(0, name,OBJPROP_COLOR, clrYellow);
   string oldName = name;
   StringReplace(name, "Horizontal Line", "Disabled");
   ObjectSetString(0, oldName,OBJPROP_NAME, name);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ModifyPosition()
  {
   for(int i = 0; i< PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetString(POSITION_SYMBOL);
      double priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double priceStopLoss =PositionGetDouble(POSITION_SL);
      long magic = PositionGetInteger(POSITION_MAGIC);
      long orderType = PositionGetInteger(POSITION_TYPE);

      if(symbol == _Symbol)
        {

         if(orderType == POSITION_TYPE_BUY)
           {
            double orderStopLoss=  NormalizeDouble(priceStopLoss, Digits());
            double newPriceStoploss=NormalizeDouble(getBid()- ChieuSau * Point(),Digits());
            if(!(orderStopLoss==0.0 || newPriceStoploss>orderStopLoss))
               break;
            if(!trade.PositionModify(ticket,newPriceStoploss,0))
              {
               Print("BUY Modify Error Code: "+ IntegerToString(GetLastError())
                     +" OP: "+DoubleToString(priceOpen,Digits())
                     +" SL: "+DoubleToString(newPriceStoploss,Digits())
                     +" Bid: "+DoubleToString(getBid(),Digits())
                     +" Ask: "+DoubleToString(getAsk(),Digits())
                     +" Spread: "+ DoubleToString(getSpreads()));
              }
            else
               Print("BUY Modify OP: "+DoubleToString(priceOpen,Digits())
                     +" SL: "+DoubleToString(newPriceStoploss,Digits())
                     +" Bid: "+DoubleToString(getBid(),Digits())
                     +" Ask: "+DoubleToString(getAsk(),Digits())
                     +" Spread: "+ DoubleToString(getSpreads()));
            break;
           }
         else
            if(orderType == POSITION_TYPE_SELL)
              {
               double orderStopLoss=  NormalizeDouble(priceStopLoss, Digits());
               double newPriceStoploss=NormalizeDouble(getAsk()+ChieuSau * Point(),Digits());

               if(!((orderStopLoss==0.0 || newPriceStoploss<orderStopLoss)))
                  break;
               if(!trade.PositionModify(ticket,newPriceStoploss,0))
                 {
                  Print("SELL Modify Error Code: "+IntegerToString(GetLastError())
                        +" OP: "+DoubleToString(priceOpen,Digits())
                        +" SL: "+DoubleToString(newPriceStoploss,Digits())
                        +" Bid: "+DoubleToString(getBid(),Digits())
                        +" Ask: "+DoubleToString(getAsk(),Digits())
                        +" Spread: "+ DoubleToString(getSpreads()));
                 }
               else
                  Print("SELL Modify OP: "+DoubleToString(priceOpen,Digits())
                        +" SL: "+DoubleToString(newPriceStoploss,Digits())
                        +" Bid: "+DoubleToString(getBid(),Digits())
                        +" Ask: "+DoubleToString(getAsk(),Digits())
                        +" Spread: "+ DoubleToString(getSpreads()));
               break;
              }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ModifyOrder()
  {
   for(int i = 0; i< OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);
      string symbol = OrderGetString(ORDER_SYMBOL);
      double priceOpen = OrderGetDouble(ORDER_PRICE_OPEN);
      double priceStopLoss = OrderGetDouble(ORDER_SL);
      long magic = OrderGetInteger(ORDER_MAGIC);
      long orderType = OrderGetInteger(ORDER_TYPE);

      if(symbol == _Symbol)
        {
         if(orderType == ORDER_TYPE_BUY_STOP)
           {
            double orderOpenPrice=NormalizeDouble(priceOpen,Digits());
            double newOpenPrice=NormalizeDouble(getAsk()+ChieuSau * Point(),Digits());
            if(!((newOpenPrice<orderOpenPrice)))
               break;
            double newStoplossPrice= NormalizeDouble(newOpenPrice -(StopLoss+ getSpreads()) * Point(),Digits());

            if(!trade.OrderModify(ticket,newOpenPrice,newStoplossPrice,0,ORDER_TIME_DAY,NULL))
              {
               Print("BUYSTOP Modify Error Code: "+IntegerToString(GetLastError())
                     +" OP: "+DoubleToString(newOpenPrice,Digits())
                     +" SL: "+DoubleToString(newStoplossPrice,Digits())
                     +" Bid: "+DoubleToString(getBid(),Digits())
                     +" Ask: "+DoubleToString(getAsk(),Digits()));
              }

            break;
           }
         else
            if(orderType == ORDER_TYPE_SELL_STOP)
              {
               double orderOpenPrice=NormalizeDouble(priceOpen,Digits());
               double newOpenPrice=NormalizeDouble(getBid()-ChieuSau * Point(),Digits());
               if(!((newOpenPrice>orderOpenPrice)))
                  break;
               double newStoplossPrice= NormalizeDouble(newOpenPrice+(StopLoss+getSpreads()) * Point(),Digits());
               if(! trade.OrderModify(ticket,newOpenPrice,newStoplossPrice,0,ORDER_TIME_DAY, NULL))
                 {
                  Print("SELLSTOP Modify Error Code: "+IntegerToString(GetLastError())
                        +" OP: "+DoubleToString(newOpenPrice,Digits())
                        +" SL: "+DoubleToString(newStoplossPrice,Digits())
                        + " Bid: "+DoubleToString(getBid(),Digits())
                        +" Ask: "+DoubleToString(getAsk(),Digits()));
                 }
              }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calcLots()
  {
   return 0.01;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenStopOrder(int mode)
  {
   double lots = calcLots();
   if(lots == 0)
      return;

   if(mode == ORDER_TYPE_BUY_STOP)
     {
      if(getSpreads()<MaxSpreads)
        {
         double tempOpenPrice = NormalizeDouble(getAsk() + ChieuSau * Point(), Digits());
         double stoplossPrice = NormalizeDouble(tempOpenPrice - (StopLoss+ getSpreads()) * Point(), Digits());

         if(!trade.BuyStop(lots, tempOpenPrice,_Symbol, stoplossPrice,0,ORDER_TIME_DAY,0,""))
           {
            Print("BUYSTOP Send Error Code: "+IntegerToString(GetLastError())
                  +" LT: "+DoubleToString(lots)
                  +" OP: "+DoubleToString(tempOpenPrice,Digits())
                  +" SL: "+DoubleToString(stoplossPrice,Digits())
                  +" Bid: "+DoubleToString(getBid(),Digits())
                  +" Ask: "+DoubleToString(getAsk(),Digits())
                  +" Spread: "+ DoubleToString(getSpreads()));
           }
        }
     }
   else
     {
      if(getSpreads() <MaxSpreads)
        {
         double tempOpenPrice = NormalizeDouble(getBid() - ChieuSau * Point(), Digits());
         double stoplossPrice = NormalizeDouble(tempOpenPrice + (StopLoss+ getSpreads()) * Point(), Digits());
         if(!trade.SellStop(lots, tempOpenPrice,_Symbol, stoplossPrice,0,ORDER_TIME_DAY,0,""))
           {
            Print("SELLSTOP Send Error Code: "+ IntegerToString(GetLastError())
                  +" LT: "+DoubleToString(lots)
                  +" OP: "+DoubleToString(tempOpenPrice,Digits())
                  +" SL: "+ DoubleToString(stoplossPrice,Digits())
                  +" Bid: "+DoubleToString(getBid(),Digits())
                  +" Ask: "+DoubleToString(getAsk(),Digits())
                  +" Spread: "+ DoubleToString(getSpreads()));
           }
        }
     }
  }
//+------------------------------------------------------------------+
long getSpreads()
  {
   return SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getAsk()
  {
   return SymbolInfoDouble(_Symbol,SYMBOL_ASK);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getBid()
  {
   return SymbolInfoDouble(_Symbol,SYMBOL_BID);
  }
//+------------------------------------------------------------------+
