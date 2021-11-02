class ChartTranslations {
  final String date;
  final String open;
  final String high;
  final String low;
  final String close;
  final String changeAmount;
  final String change;
  final String amount;

  const ChartTranslations({
    this.date = 'Date',
    this.open = 'Open',
    this.high = 'High',
    this.low = 'Low',
    this.close = 'Close',
    this.changeAmount = 'Change',
    this.change = 'Change%',
    this.amount = 'Amount',
  });

  String byIndex(int index) {
    switch (index) {
      case 0:
        return date;
      case 1:
        return open;
      case 2:
        return close;
      case 3:
        return high;
      case 4:
        return low;
      case 5:
        return amount;
      case 6:
        return changeAmount;
      case 7:
        return change;
    }

    throw UnimplementedError();
  }
}

const kChartTranslations = {
  'ko_KR': ChartTranslations(
    date: '날짜',
    open: '시가',
    high: '최고',
    low: '최저',
    close: '종가',
    changeAmount: '변화 총량',
    change: '변화량',
    amount: '거래량',
  ),
};
