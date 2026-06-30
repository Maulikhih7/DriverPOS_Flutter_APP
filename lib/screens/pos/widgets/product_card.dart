import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/product_model.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: _productImage(),
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${product.effectivePrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        if (product.stock != null)
                          Text(
                            'Qty: ${product.stock}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productImage() {
    final url = product.image;
    if (url == null || url.isEmpty) return _placeholder();
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _placeholder();
      },
      errorBuilder: (context, error, stack) => _placeholder(),
    );
  }

  Widget _placeholder() {
    final color = _deptColor(product.department);
    return Container(
      color: color.withValues(alpha: 0.12),
      child: Center(
        child: Icon(_deptIcon(product.department), color: color, size: 36),
      ),
    );
  }

  static Color _deptColor(String? dept) {
    switch (dept) {
      case 'Green Fees':   return AppColors.primary;
      case 'Pro Shop':     return const Color(0xFF5C6BC0);
      case 'Food & Bev':   return const Color(0xFFEF6C00);
      case 'Cart Rentals': return const Color(0xFF00897B);
      case 'Lessons':      return const Color(0xFF8E24AA);
      default:             return AppColors.textMuted;
    }
  }

  static IconData _deptIcon(String? dept) {
    switch (dept) {
      case 'Green Fees':   return Icons.golf_course;
      case 'Pro Shop':     return Icons.store;
      case 'Food & Bev':   return Icons.restaurant;
      case 'Cart Rentals': return Icons.directions_car;
      case 'Lessons':      return Icons.school;
      default:             return Icons.inventory_2_outlined;
    }
  }
}
