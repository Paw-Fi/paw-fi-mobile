import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_html/flutter_html.dart';

/// Shows scenario analysis result bottom sheet
void showScenarioResultSheet(
  BuildContext context, {
  required String question,
  required String targetDate,
  required String advice,
}) {
  final colorScheme = shadcnui.Theme.of(context).colorScheme;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: colorScheme.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.mutedForeground.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Scenario Analysis',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.foreground,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colorScheme.foreground),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.border, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.lightbulb_outline,
                              color: colorScheme.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Question Label
                          Text(
                            'Your Question',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Question Text
                          Text(
                            'Can I $question',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Target Date
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: colorScheme.mutedForeground,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Target Date: ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                              Text(
                                targetDate,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.foreground,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Analysis Result
                    Text(
                      'AI Analysis',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.border,
                          width: 1,
                        ),
                      ),
                      child: Html(
                        data: md.markdownToHtml(advice),
                        style: {
                          "body": Style(
                            fontSize: FontSize(15),
                            lineHeight: const LineHeight(1.6),
                            color: colorScheme.foreground,
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                          ),
                          "p": Style(
                            fontSize: FontSize(15),
                            lineHeight: const LineHeight(1.6),
                            color: colorScheme.foreground,
                            margin: Margins.only(bottom: 12),
                          ),
                          "h1": Style(
                            fontSize: FontSize(24),
                            fontWeight: FontWeight.bold,
                            color: colorScheme.foreground,
                            margin: Margins.only(top: 16, bottom: 12),
                          ),
                          "h2": Style(
                            fontSize: FontSize(20),
                            fontWeight: FontWeight.bold,
                            color: colorScheme.foreground,
                            margin: Margins.only(top: 14, bottom: 10),
                          ),
                          "h3": Style(
                            fontSize: FontSize(18),
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                            margin: Margins.only(top: 12, bottom: 8),
                          ),
                          "strong": Style(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.foreground,
                          ),
                          "em": Style(
                            fontStyle: FontStyle.italic,
                            color: colorScheme.foreground,
                          ),
                          "ul": Style(
                            margin: Margins.only(left: 16, bottom: 12),
                          ),
                          "ol": Style(
                            margin: Margins.only(left: 16, bottom: 12),
                          ),
                          "li": Style(
                            fontSize: FontSize(15),
                            lineHeight: const LineHeight(1.6),
                            color: colorScheme.foreground,
                            margin: Margins.only(bottom: 4),
                          ),
                          "code": Style(
                            fontSize: FontSize(14),
                            fontFamily: 'monospace',
                            color: colorScheme.foreground,
                            backgroundColor: colorScheme.muted,
                            padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
                          ),
                          "pre": Style(
                            fontSize: FontSize(14),
                            fontFamily: 'monospace',
                            color: colorScheme.foreground,
                            backgroundColor: colorScheme.muted,
                            padding: HtmlPaddings.all(12),
                            margin: Margins.only(bottom: 12),
                            border: Border.all(color: colorScheme.border),
                          ),
                          "blockquote": Style(
                            fontSize: FontSize(15),
                            fontStyle: FontStyle.italic,
                            color: colorScheme.mutedForeground,
                            backgroundColor: colorScheme.muted,
                            padding: HtmlPaddings.all(12),
                            margin: Margins.only(bottom: 12),
                            border: Border(
                              left: BorderSide(
                                color: colorScheme.primary,
                                width: 4,
                              ),
                            ),
                          ),
                          "a": Style(
                            color: colorScheme.primary,
                            textDecoration: TextDecoration.underline,
                          ),
                          "hr": Style(
                            margin: Margins.symmetric(vertical: 16),
                            border: Border(
                              bottom: BorderSide(
                                color: colorScheme.border,
                                width: 1,
                              ),
                            ),
                          ),
                        },
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
