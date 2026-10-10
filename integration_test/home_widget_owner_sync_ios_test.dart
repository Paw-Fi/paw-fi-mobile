import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:integration_test/integration_test.dart';
import 'package:moneko/core/services/widget_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iOS native widget storage survives startup and owner changes',
      (tester) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    await HomeWidget.setAppGroupId('group.moneko.mobile');
    final previousOwner =
        await HomeWidget.getWidgetData<String>('widget_user_id');
    final previousCurrency =
        await HomeWidget.getWidgetData<String>('selected_widget_currency');

    try {
      await HomeWidget.saveWidgetData(
          'widget_user_id', 'widget-startup-test-initial');
      for (final owner in [
        '',
        'widget-startup-test-1',
        'widget-startup-test-2',
        ''
      ]) {
        await HomeWidget.saveWidgetData('selected_widget_currency', 'EUR');
        await WidgetService().synchronizeOwner(owner);
        expect(await HomeWidget.getWidgetData<String>('widget_user_id'), owner);
        expect(
            await HomeWidget.getWidgetData<String>('selected_widget_currency'),
            isEmpty);
      }
    } finally {
      // Never send null through home_widget 0.9.1's iOS UserDefaults bridge.
      await HomeWidget.saveWidgetData('widget_user_id', previousOwner ?? '');
      await HomeWidget.saveWidgetData(
          'selected_widget_currency', previousCurrency ?? '');
      await WidgetService().reloadWidgets();
    }
  });
}
