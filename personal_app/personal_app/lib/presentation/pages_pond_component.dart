import 'package:flood/flood.dart';
import 'package:personal_app/presentation/pages/home_page.dart';

class PagesAppPondComponent with IsAppPondComponent {
  @override
  Map<Route, AppPage> get pages => {
        HomeRoute(): HomePage(),
        // TODO As you create AppPages, add them here.
      };
}
