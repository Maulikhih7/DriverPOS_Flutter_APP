import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/product_model.dart';

class ProductCard extends StatefulWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final ValueChanged<int>? onAddMultiple;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onAddMultiple,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      onLongPress: () => _showQtyPicker(context),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _pressed ? AppColors.primary.withOpacity(0.4) : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _pressed ? 0.08 : 0.04),
                blurRadius: _pressed ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: _productImage(),
                ),
              ),
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
                        widget.product.name,
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
                            '\$${widget.product.effectivePrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          if (widget.product.stock != null)
                            Text(
                              'Qty: ${widget.product.stock}',
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
      ),
    );
  }

  void _showQtyPicker(BuildContext context) {
    HapticFeedback.mediumImpact();
    int qty = 1;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setQtyState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          title: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _deptColor(widget.product.department).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_deptIcon(widget.product.department),
                    color: _deptColor(widget.product.department), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.product.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('\$${widget.product.effectivePrice.toStringAsFixed(2)} each',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _QtyBtn(
                    icon: Icons.remove_rounded,
                    enabled: qty > 1,
                    onTap: () => setQtyState(() => qty = (qty - 1).clamp(1, 99)),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 60, height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$qty',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                  ),
                  const SizedBox(width: 12),
                  _QtyBtn(
                    icon: Icons.add_rounded,
                    enabled: qty < 99,
                    onTap: () => setQtyState(() => qty = (qty + 1).clamp(1, 99)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    Text(
                      '\$${(qty * widget.product.effectivePrice).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                HapticFeedback.lightImpact();
                if (widget.onAddMultiple != null) {
                  widget.onAddMultiple!(qty);
                } else {
                  for (int k = 0; k < qty; k++) widget.onTap();
                }
              },
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
              label: Text('Add $qty to Cart'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productImage() {
    final url = widget.product.image;
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
    final color = _deptColor(widget.product.department);
    return Container(
      color: color.withValues(alpha: 0.12),
      child: Center(
        child: Icon(_deptIcon(widget.product.department), color: color, size: 36),
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

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primary : AppColors.border,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
