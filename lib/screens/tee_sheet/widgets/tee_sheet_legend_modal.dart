import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mirrors the web's "Tee Sheet Icons & Colors" info modal exactly —
/// same labels, same hex values, sourced from the backend's canonical
/// color table (golfpro-backend-main/data/teesheetColor.js:
/// INDIVIDUAL_SLOT_BG_COLOR / COMBINE_SLOT_BG_COLOR.CAPSULE).
class TeeSheetLegendModal extends StatelessWidget {
  const TeeSheetLegendModal({super.key});

  static const _badgeColor = Color(0xFFA5A3AB); // CAPSULE constant

  static const _statuses = [
    ('Booked / Reserved', Color(0xFFF6F4FF)),
    ('Checked In', Color(0xFF6BBBFF)),
    ("Tee'd Off", Color(0xFFA1D6B2)),
    ('Turn', Color(0xFFD6C0B3)),
    ('Rain Check', Color(0xFFA594F9)),
    ('Completed', Color(0xFFE7F0DC)),
    ('No Showed', Color(0xFFFF8A8A)),
    ('No Show Fee Taken', Color(0xFFCCE3F9)),
  ];

  static const _icons = [
    ('Online Reservation', 'assets/images/teesheet_online.png'),
    ('Golf Cart', 'assets/images/teesheet_golf_cart.png'),
    ('Rental Clubs', 'assets/images/teesheet_rental_clubs.png'),
    ('Handicap', 'assets/images/teesheet_handicap.png'),
    ('Rain Check', 'assets/images/teesheet_raincheck.png'),
    ('Pre Authorized', 'assets/images/teesheet_preauth.png'),
    ("Don't Charge No Show Fee", 'assets/images/teesheet_prevent_noshow.png'),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6FA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF244065),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tee Sheet Icons & Colors',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 5.2,
                      children: [
                        for (final (label, color) in _statuses)
                          _StatusPill(label: label, color: color),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 28,
                      runSpacing: 14,
                      children: [
                        for (final (label, asset) in _icons)
                          _IconLegendItem(label: label, asset: asset),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: const Color(0xFFB8D4B0)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              color: TeeSheetLegendModal._badgeColor,
              alignment: Alignment.center,
              child: Text(
                '18',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconLegendItem extends StatelessWidget {
  final String label;
  final String asset;
  const _IconLegendItem({required this.label, required this.asset});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(asset, width: 20, height: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }
}
