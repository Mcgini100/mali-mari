import 'package:flutter/material.dart';

/// Category icons are stored as stable string keys so the database never
/// depends on Flutter's icon codepoints.
IconData categoryIcon(String? key) {
  switch (key) {
    case 'groceries':
      return Icons.shopping_basket_rounded;
    case 'transport':
      return Icons.directions_bus_rounded;
    case 'airtime':
      return Icons.phone_android_rounded;
    case 'rent':
      return Icons.home_rounded;
    case 'school':
      return Icons.school_rounded;
    case 'electricity':
      return Icons.bolt_rounded;
    case 'water':
      return Icons.water_drop_rounded;
    case 'church':
      return Icons.volunteer_activism_rounded;
    case 'family':
      return Icons.family_restroom_rounded;
    case 'fees':
      return Icons.receipt_long_rounded;
    case 'health':
      return Icons.local_hospital_rounded;
    case 'eating_out':
      return Icons.restaurant_rounded;
    case 'savings':
      return Icons.savings_rounded;
    case 'salary':
      return Icons.work_rounded;
    case 'side_hustle':
      return Icons.storefront_rounded;
    case 'remittance':
      return Icons.flight_land_rounded;
    case 'income_other':
      return Icons.add_circle_outline_rounded;
    case 'cash_out':
      return Icons.payments_rounded;
    default:
      return Icons.more_horiz_rounded;
  }
}
