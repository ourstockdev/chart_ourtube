import 'dart:async';

import 'package:flutter/material.dart';
import 'package:chart_ourtube/chart_translations.dart';
import 'package:chart_ourtube/extension/map_ext.dart';
import 'package:chart_ourtube/chart_ourtube.dart';

enum MainState { MA, BOLL, NONE }
enum SecondaryState { MACD, KDJ, RSI, WR, CCI, NONE }
enum TimeInterval { MIN_5, MIN_30, HOUR_1, DAY_1, MONTH_1 }

class TimeFormat {
  static const List<String> MONTH_DAY = [mm, '.', dd];
  static const List<String> YEAR_MONTH = [yyyy, '.', mm];
  static const List<String> HOUR_MINUTE = [HH, ':', nn];
}

class KChartWidget extends StatefulWidget {
  final List<KLineEntity>? datas;
  final MainState mainState;
  final bool volHidden;
  final SecondaryState secondaryState;
  final Function()? onSecondaryTap;
  final bool isLine;
  final bool hideGrid;
  @Deprecated('Use `translations` instead.')
  final bool isKorean;
  final bool showNowPrice;
  final Map<String, ChartTranslations> translations;
  final TimeInterval timeInterval;

  //当屏幕滚动到尽头会调用，真为拉到屏幕右侧尽头，假为拉到屏幕左侧尽头
  final Function(bool)? onLoadMore;
  final List<Color>? bgColor;
  final int fixedLength;
  final List<int> maDayList;
  final int flingTime;
  final double flingRatio;
  final Curve flingCurve;
  final Function(bool)? isOnDrag;
  final ChartColors chartColors;
  final ChartStyle chartStyle;

  KChartWidget(
    this.datas,
    this.chartStyle,
    this.chartColors, {
    this.mainState = MainState.MA,
    this.secondaryState = SecondaryState.MACD,
    this.onSecondaryTap,
    this.volHidden = false,
    this.isLine = false,
    this.hideGrid = false,
    this.isKorean = false,
    this.showNowPrice = true,
    this.translations = kChartTranslations,
    required this.timeInterval,
    this.onLoadMore,
    this.bgColor,
    this.fixedLength = 0,
    this.maDayList = const [5, 10, 20],
    this.flingTime = 600,
    this.flingRatio = 0.5,
    this.flingCurve = Curves.decelerate,
    this.isOnDrag,
  });

  @override
  _KChartWidgetState createState() => _KChartWidgetState();
}

class _KChartWidgetState extends State<KChartWidget>
    with TickerProviderStateMixin {
  double mScaleX = 1.0, mScrollX = 0.0, mSelectX = 0.0;
  StreamController<InfoWindowEntity?>? mInfoWindowStream;
  double mWidth = 0;
  AnimationController? _controller;
  Animation<double>? aniX;

  double getMinScrollX() {
    return mScaleX;
  }

  double _lastScale = 1.0;
  bool isScale = false, isDrag = false, isLongPress = false;

  @override
  void initState() {
    super.initState();
    mInfoWindowStream = StreamController<InfoWindowEntity?>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    mWidth = MediaQuery.of(context).size.width;
  }

  @override
  void dispose() {
    mInfoWindowStream?.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.datas != null && widget.datas!.isEmpty) {
      mScrollX = mSelectX = 0.0;
      mScaleX = 1.0;
    }
    final _painter = ChartPainter(
      widget.chartStyle,
      widget.chartColors,
      datas: widget.datas,
      scaleX: mScaleX,
      scrollX: mScrollX,
      selectX: mSelectX,
      isLongPass: isLongPress,
      mainState: widget.mainState,
      volHidden: widget.volHidden,
      secondaryState: widget.secondaryState,
      isLine: widget.isLine,
      hideGrid: widget.hideGrid,
      showNowPrice: widget.showNowPrice,
      sink: mInfoWindowStream?.sink,
      bgColor: widget.bgColor,
      fixedLength: widget.fixedLength,
      maDayList: widget.maDayList,
      is1Day: widget.timeInterval == TimeInterval.DAY_1
    );
    return GestureDetector(
      onTapUp: (details) {
        if (widget.onSecondaryTap != null &&
            _painter.isInSecondaryRect(details.localPosition)) {
          widget.onSecondaryTap!();
        }
      },
      onHorizontalDragDown: (details) {
        _stopAnimation();
        _onDragChanged(true);
      },
      onHorizontalDragUpdate: (details) {
        if (isScale || isLongPress) return;
        mScrollX = (details.primaryDelta! / mScaleX + mScrollX)
            .clamp(0.0, ChartPainter.maxScrollX)
            .toDouble();
        notifyChanged();
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        var velocity = details.velocity.pixelsPerSecond.dx;
        _onFling(velocity);
      },
      onHorizontalDragCancel: () => _onDragChanged(false),
      onScaleStart: (_) {
        isScale = true;
      },
      onScaleUpdate: (details) {
        if (isDrag || isLongPress) return;
        mScaleX = (_lastScale * details.scale).clamp(0.5, 2.2);
        notifyChanged();
      },
      onScaleEnd: (_) {
        isScale = false;
        _lastScale = mScaleX;
      },
      onLongPressStart: (details) {
        isLongPress = true;
        if (mSelectX != details.globalPosition.dx) {
          mSelectX = details.globalPosition.dx;
          notifyChanged();
        }
      },
      onLongPressMoveUpdate: (details) {
        if (mSelectX != details.globalPosition.dx) {
          mSelectX = details.globalPosition.dx;
          notifyChanged();
        }
      },
      onLongPressEnd: (details) {
        isLongPress = false;
        mInfoWindowStream?.sink.add(null);
        notifyChanged();
      },
      child: Stack(
        children: <Widget>[
          CustomPaint(
            size: Size(double.infinity, double.infinity),
            painter: _painter,
          ),
          _buildInfoDialog()
        ],
      ),
    );
  }

  void _stopAnimation({bool needNotify = true}) {
    if (_controller != null && _controller!.isAnimating) {
      _controller!.stop();
      _onDragChanged(false);
      if (needNotify) {
        notifyChanged();
      }
    }
  }

  void _onDragChanged(bool isOnDrag) {
    isDrag = isOnDrag;
    if (widget.isOnDrag != null) {
      widget.isOnDrag!(isDrag);
    }
  }

  void _onFling(double x) {
    _controller = AnimationController(
        duration: Duration(milliseconds: widget.flingTime), vsync: this);
    aniX = null;
    aniX = Tween<double>(begin: mScrollX, end: x * widget.flingRatio + mScrollX)
        .animate(CurvedAnimation(
            parent: _controller!.view, curve: widget.flingCurve));
    aniX!.addListener(() {
      mScrollX = aniX!.value;
      if (mScrollX <= 0) {
        mScrollX = 0;
        if (widget.onLoadMore != null) {
          widget.onLoadMore!(true);
        }
        _stopAnimation();
      } else if (mScrollX >= ChartPainter.maxScrollX) {
        mScrollX = ChartPainter.maxScrollX;
        if (widget.onLoadMore != null) {
          widget.onLoadMore!(false);
        }
        _stopAnimation();
      }
      notifyChanged();
    });
    aniX!.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _onDragChanged(false);
        notifyChanged();
      }
    });
    _controller!.forward();
  }

  void notifyChanged() => setState(() {});

  late List<String> infos;

  Widget _buildInfoDialog() {
    return StreamBuilder<InfoWindowEntity?>(
        stream: mInfoWindowStream?.stream,
        builder: (context, snapshot) {
          if (!isLongPress ||
              widget.isLine == true ||
              !snapshot.hasData ||
              snapshot.data?.kLineEntity == null) return Container();
          KLineEntity entity = snapshot.data!.kLineEntity;
          //double upDown = entity.change ?? entity.close - entity.open;
          if(widget.timeInterval == TimeInterval.MIN_5 || widget.timeInterval == TimeInterval.MIN_30 || widget.timeInterval == TimeInterval.HOUR_1) {
            infos = [
              getDateWithStartTime(entity.time),
              getFormattingNumber(entity.open),
              getFormattingNumber(entity.close),
              getFormattingNumber(entity.high),
              getFormattingNumber(entity.low),
              getFormattingNumber(entity.amount)
            ];
          } else {
            infos = [
              getDate(entity.time),
              getFormattingNumber(entity.open),
              getFormattingNumber(entity.close),
              getFormattingNumber(entity.high),
              getFormattingNumber(entity.low),
              getFormattingNumber(entity.amount)
            ];
          }

          return Container(
            margin: EdgeInsets.only(
                left: snapshot.data!.isLeft ? 4 : mWidth - mWidth / 3 - 4,
                top: 25),
            width: mWidth / 3,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
                color: widget.chartColors.selectFillColor,
                border: Border.all(color: widget.chartColors.selectBorderColor, width: 0.5),
                borderRadius: BorderRadius.circular(4)
            ),
            child: ListView.builder(
              padding: EdgeInsets.all(4),
              itemCount: infos.length,
              shrinkWrap: true,
              itemBuilder: (context, index) {
                final translations = widget.isKorean
                    ? kChartTranslations['ko_KR']!
                    : widget.translations.of(context);

                if(index == 0 && (widget.timeInterval == TimeInterval.MIN_5 || widget.timeInterval == TimeInterval.MIN_30 || widget.timeInterval == TimeInterval.HOUR_1)) {
                  List<String> dateTimeStr = infos[0].split(',');

                  return Container(
                    margin: EdgeInsets.only(right: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                            dateTimeStr[0],
                            style: TextStyle(
                                color: widget.chartColors.infoWindowTitleColor,
                                fontSize: 12.0,
                                fontWeight: FontWeight.w400
                            )
                        ),
                        Text(
                            dateTimeStr[1],
                            style: TextStyle(
                                color: widget.chartColors.infoWindowTitleColor,
                                fontSize: 10.0,
                                fontWeight: FontWeight.w400
                            )
                        ),
                      ],
                    ),
                  );
                } else if(index == 0) {
                  return Text(
                      infos[0],
                      style: TextStyle(
                          color: widget.chartColors.infoWindowTitleColor,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w400
                      )
                  );
                } else if(index == 3) {
                  return _buildItem(
                      infos[3],
                      translations.byIndex(3),
                      flag: 1
                  );
                } else if(index == 4) {
                  return _buildItem(
                    infos[4],
                    translations.byIndex(4),
                    flag: -1
                  );
                } else {
                  return _buildItem(
                    infos[index],
                    translations.byIndex(index),
                  );
                }
              },
            ),
          );
        });
  }

  Widget _buildItem(String info, String infoName, {int flag=0}) {
    Color color = widget.chartColors.infoWindowNormalColor;
    if (info.startsWith('+') || flag==1) {
      color = widget.chartColors.infoWindowUpColor;
    } else if (info.startsWith("-") || flag==-1) {
      color = widget.chartColors.infoWindowDnColor;
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
              child: Text(infoName,
                  style: TextStyle(
                      color: widget.chartColors.infoWindowNormalColor,
                      fontSize: 12.0,
                      fontWeight: FontWeight.w400))),
          Text(info, style: TextStyle(color: color, fontSize: 12.0, fontWeight: FontWeight.w400)),
        ],
      )
    );
  }

  String getDate(int? date) => dateFormat(
      DateTime.fromMillisecondsSinceEpoch(
          date ?? DateTime.now().millisecondsSinceEpoch),
          (widget.timeInterval == TimeInterval.DAY_1) ? TimeFormat.MONTH_DAY : TimeFormat.YEAR_MONTH);

  String getDateWithStartTime(int? date) {
    if(date == null) {
      return getDate(date);
    }

    String end =
      (widget.timeInterval == TimeInterval.MIN_5) ? dateFormat(DateTime.fromMillisecondsSinceEpoch(date+300000), TimeFormat.HOUR_MINUTE)
      : (widget.timeInterval == TimeInterval.MIN_30) ? dateFormat(DateTime.fromMillisecondsSinceEpoch(date+1800000), TimeFormat.HOUR_MINUTE)
      : dateFormat(DateTime.fromMillisecondsSinceEpoch(date+3600000), TimeFormat.HOUR_MINUTE);

    return
      dateFormat(DateTime.fromMillisecondsSinceEpoch(date), TimeFormat.MONTH_DAY)
      + ','
      + dateFormat(DateTime.fromMillisecondsSinceEpoch(date), TimeFormat.HOUR_MINUTE)
      + '-'
      + end;
  }

  String getFormattingNumber(double num) {
    return num.toStringAsFixed(widget.fixedLength).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
}
