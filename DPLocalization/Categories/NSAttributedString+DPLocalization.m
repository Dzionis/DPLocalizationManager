//
//  NSAttributedString+DPLocalization.m
//  DP Commons
//
//  Created by dmitriy.petrusevich on 03.11.14.
//  Copyright (c) 2014 Dmitriy Petrusevich. All rights reserved.
//

#import "NSAttributedString+DPLocalization.h"
#import "DPLocalizationManager.h"

@implementation NSAttributedString (DPLocalization)

+ (NSAttributedString *)dp_attibutedStringWithString:(NSString *)string font:(DPFont *)font textColor:(DPColor *)textColor {
    NSMutableAttributedString *attrsString = nil;

    if (string) {
        static NSRegularExpression *tagRegExp = nil;
        static NSRegularExpression *replaceRegExp = nil;

        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            tagRegExp = [NSRegularExpression regularExpressionWithPattern:@"<([^<]*?)>\\{(.*?)\\}" options:NSRegularExpressionDotMatchesLineSeparators error:nil];
            replaceRegExp = [NSRegularExpression regularExpressionWithPattern:@"\\[<([^<]*?)>\\]" options:NSRegularExpressionDotMatchesLineSeparators error:nil];
        });

        NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
        [attrs setValue:font forKey:NSFontAttributeName];
        [attrs setValue:textColor forKey:NSForegroundColorAttributeName];

        attrsString = [[NSMutableAttributedString alloc] initWithString:string attributes:attrs];

        NSArray *matches = [tagRegExp matchesInString:string options:kNilOptions range:NSMakeRange(0, string.length)];
        [matches enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult *match, NSUInteger idx, BOOL *stop) {

            NSString *textString = [string substringWithRange:[match rangeAtIndex:2]];
            NSString *styleString = [string substringWithRange:[match rangeAtIndex:1]];

            NSMutableDictionary *tagAttrs = [attrs mutableCopy];
            [tagAttrs setValuesForKeysWithDictionary:[self stylesFromSting:styleString font:font]];

            NSAttributedString *replaceString = [[NSAttributedString alloc] initWithString:textString attributes:tagAttrs];
            [attrsString replaceCharactersInRange:match.range withAttributedString:replaceString];
        }];

        matches = [replaceRegExp matchesInString:attrsString.string options:kNilOptions range:NSMakeRange(0, attrsString.string.length)];
        [matches enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult *match, NSUInteger idx, BOOL *stop) {
            NSString *infoString = [attrsString.string substringWithRange:[match rangeAtIndex:1]];

            NSDictionary *attrs = [attrsString attributesAtIndex:match.range.location effectiveRange:NULL];
            UIFont *effectiveFont = attrs[NSFontAttributeName] ?: font;

            NSAttributedString *replaceString = [self replacementFromSting:infoString font:effectiveFont];
            if (replaceString != nil) {
                [attrsString replaceCharactersInRange:match.range withAttributedString:replaceString];
                [attrsString addAttributes:attrs range:NSMakeRange(match.range.location, replaceString.length)];
            }
        }];
    }

    return attrsString;
}

+ (NSDictionary *)stylesFromSting:(NSString *)styleString font:(DPFont *)font {
    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];

    static NSRegularExpression *nameExp = nil;
    static NSRegularExpression *colorExp = nil;
    static NSRegularExpression *sizeExp = nil;
    static NSRegularExpression *traitsExp = nil;
    static NSRegularExpression *linkExp = nil;
    static NSRegularExpression *paragraphSpacingExp = nil;
    static NSRegularExpression *lineSpacingExp = nil;
    static NSRegularExpression *kerningExp = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nameExp = [NSRegularExpression regularExpressionWithPattern:@"name=\"(.+?)\"" options:NSRegularExpressionCaseInsensitive error:nil];
        colorExp = [NSRegularExpression regularExpressionWithPattern:@"color=([0-9]{1,3}),([0-9]{1,3}),([0-9]{1,3})(,[0-9]{1,3})?" options:NSRegularExpressionCaseInsensitive error:nil];
        traitsExp = [NSRegularExpression regularExpressionWithPattern:@"traits=([!buis]+)" options:NSRegularExpressionCaseInsensitive error:nil];
        sizeExp = [NSRegularExpression regularExpressionWithPattern:@"size=([0-9.]+)" options:NSRegularExpressionCaseInsensitive error:nil];
        linkExp = [NSRegularExpression regularExpressionWithPattern:@"link=\"(.+?)\"" options:NSRegularExpressionCaseInsensitive error:nil];
        paragraphSpacingExp = [NSRegularExpression regularExpressionWithPattern:@"paragraph_spacing=([0-9.]+)" options:NSRegularExpressionCaseInsensitive error:nil];
        lineSpacingExp = [NSRegularExpression regularExpressionWithPattern:@"line_spacing=([0-9.]+)" options:NSRegularExpressionCaseInsensitive error:nil];
        kerningExp = [NSRegularExpression regularExpressionWithPattern:@"kerning=([0-9.]+)" options:NSRegularExpressionCaseInsensitive error:nil];
    });

    NSRange allStringRange = NSMakeRange(0, styleString.length);

    NSString *fontName = font.fontName;
    CGFloat fontSize = font.pointSize;

    NSTextCheckingResult *sizeCheck = [sizeExp firstMatchInString:styleString options:kNilOptions range:allStringRange];
    if (sizeCheck) fontSize = [[styleString substringWithRange:[sizeCheck rangeAtIndex:1]] floatValue];

    NSTextCheckingResult *nameCheck = [nameExp firstMatchInString:styleString options:kNilOptions range:allStringRange];
    if (nameCheck) fontName = [styleString substringWithRange:[nameCheck rangeAtIndex:1]];

    NSTextCheckingResult *colorCheck = [colorExp firstMatchInString:styleString options:kNilOptions range:allStringRange];
    if (colorCheck) {
        CGFloat r = [[styleString substringWithRange:[colorCheck rangeAtIndex:1]] floatValue] / 255.0;
        CGFloat g = [[styleString substringWithRange:[colorCheck rangeAtIndex:2]] floatValue] / 255.0;
        CGFloat b = [[styleString substringWithRange:[colorCheck rangeAtIndex:3]] floatValue] / 255.0;
        CGFloat a = ([colorCheck rangeAtIndex:4].location != NSNotFound) ? ([[[styleString substringWithRange:[colorCheck rangeAtIndex:4]] substringFromIndex:1] floatValue] / 255.0) : 1.0;
        [attrs setValue:[DPColor colorWithRed:r green:g blue:b alpha:a] forKey:NSForegroundColorAttributeName];
    }
    
    NSTextCheckingResult *paragraphSpacingCheck = [paragraphSpacingExp firstMatchInString:styleString options:kNilOptions range:allStringRange];
    if (paragraphSpacingCheck) {
        NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        style.paragraphSpacing = [[styleString substringWithRange:[paragraphSpacingCheck rangeAtIndex:1]] floatValue];
        [attrs setValue:style forKey:NSParagraphStyleAttributeName];
    }
    
    NSTextCheckingResult *lineSpacingCheck = [lineSpacingExp firstMatchInString:styleString options:kNilOptions range:allStringRange];
    if (lineSpacingCheck) {
        NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        style.lineSpacing = [[styleString substringWithRange:[lineSpacingCheck rangeAtIndex:1]] floatValue];
        [attrs setValue:style forKey:NSParagraphStyleAttributeName];
    }
    
    NSTextCheckingResult *kerningCheck = [kerningExp firstMatchInString:styleString options:kNilOptions range:allStringRange];
    if (kerningCheck) {
        [attrs setValue:@([[styleString substringWithRange:[kerningCheck rangeAtIndex:1]] floatValue]) forKey:NSKernAttributeName];
    }

    DPFont *styleFont = font ? [DPFont fontWithName:fontName size:fontSize] : nil;

#if DPLocalization_UIKit
    if (NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_7_0) {
        [attrs setValue:styleFont forKey:NSFontAttributeName];

        NSTextCheckingResult *traitsCheck = [traitsExp firstMatchInString:styleString options:kNilOptions range:allStringRange];
        if (traitsCheck) {
            NSString *traitsString = [styleString substringWithRange:[traitsCheck rangeAtIndex:1]];
            if ([traitsString rangeOfString:@"u"].location != NSNotFound) [attrs setValue:@(NSUnderlineStyleSingle) forKey:NSUnderlineStyleAttributeName];
            if ([traitsString rangeOfString:@"s"].location != NSNotFound) [attrs setValue:@(NSUnderlineStyleSingle) forKey:NSStrikethroughStyleAttributeName];

            // Not used - will be useful in futher releases
            if ([traitsString rangeOfString:@"!u"].location != NSNotFound) [attrs setValue:@(NSUnderlineStyleNone) forKey:NSUnderlineStyleAttributeName];
            if ([traitsString rangeOfString:@"!s"].location != NSNotFound) [attrs setValue:@(NSUnderlineStyleNone) forKey:NSStrikethroughStyleAttributeName];
        }
    }
    else
#endif
    {
        NSTextCheckingResult *linkCheck = [linkExp firstMatchInString:styleString options:kNilOptions range:allStringRange];
        if (linkCheck) {
            NSString *link = [styleString substringWithRange:[linkCheck rangeAtIndex:1]];
            NSURL *url = [NSURL URLWithString:link];
            [attrs setValue:url ? url : link forKey:NSLinkAttributeName];
        }

        NSTextCheckingResult *traitsCheck = [traitsExp firstMatchInString:styleString options:kNilOptions range:allStringRange];
        if (traitsCheck) {
            NSString *traitsString = [styleString substringWithRange:[traitsCheck rangeAtIndex:1]];
            DPFontSymbolicTraits traits = [[styleFont fontDescriptor] symbolicTraits];

            if ([traitsString rangeOfString:@"b"].location != NSNotFound) traits |= DPFontTraitBold;
            if ([traitsString rangeOfString:@"i"].location != NSNotFound) traits |= DPFontTraitItalic;
            if ([traitsString rangeOfString:@"!b"].location != NSNotFound) traits &= (~DPFontTraitBold);
            if ([traitsString rangeOfString:@"!i"].location != NSNotFound) traits &= (~DPFontTraitItalic);

            if ([traitsString rangeOfString:@"u"].location != NSNotFound) [attrs setValue:@(NSUnderlineStyleSingle) forKey:NSUnderlineStyleAttributeName];
            if ([traitsString rangeOfString:@"s"].location != NSNotFound) [attrs setValue:@(NSUnderlineStyleSingle) forKey:NSStrikethroughStyleAttributeName];

            // Not used - will be useful in futher releases
            if ([traitsString rangeOfString:@"!u"].location != NSNotFound) [attrs setValue:@(NSUnderlineStyleNone) forKey:NSUnderlineStyleAttributeName];
            if ([traitsString rangeOfString:@"!s"].location != NSNotFound) [attrs setValue:@(NSUnderlineStyleNone) forKey:NSStrikethroughStyleAttributeName];

            DPFontDescriptor *fontDescriptor = [[styleFont fontDescriptor] fontDescriptorWithSymbolicTraits:traits];
            [attrs setValue:[DPFont fontWithDescriptor:fontDescriptor size:fontSize] forKey:NSFontAttributeName];
        }
        else {
            [attrs setValue:styleFont forKey:NSFontAttributeName];
        }
    }

    return attrs;
}

+ (NSAttributedString *)replacementFromSting:(NSString *)infoString font:(DPFont *)font {
    static NSRegularExpression *imageExp = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        imageExp = [NSRegularExpression regularExpressionWithPattern:@"img=\"(.+?)\"(\\ssize=\\(([0-9.]+);([0-9.]+)\\))?(\\soffset=\\(([-0-9.]+);([-0-9.]+)\\))?" options:NSRegularExpressionCaseInsensitive error:nil];
    });

    NSRange allStringRange = NSMakeRange(0, infoString.length);

    NSTextCheckingResult *imageCheck = [imageExp firstMatchInString:infoString options:kNilOptions range:allStringRange];
    if (imageCheck) {
        NSString *imageName = [infoString substringWithRange:[imageCheck rangeAtIndex:1]];
        DPImage *image = [[DPLocalizationManager currentManager] localizedImageNamed:imageName];

        CGFloat width = image.size.width;
        CGFloat height = image.size.height;
        CGFloat xOffset = 0;
        CGFloat yOffset = font.descender;

        if ([imageCheck rangeAtIndex:2].location != NSNotFound) {
            width = [[infoString substringWithRange:[imageCheck rangeAtIndex:3]] floatValue];
            height = [[infoString substringWithRange:[imageCheck rangeAtIndex:4]] floatValue];
        }

        if ([imageCheck rangeAtIndex:5].location != NSNotFound) {
            xOffset = [[infoString substringWithRange:[imageCheck rangeAtIndex:6]] floatValue];
            yOffset = [[infoString substringWithRange:[imageCheck rangeAtIndex:7]] floatValue];
        }

        NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
        textAttachment.image = image;
        textAttachment.bounds = CGRectMake(xOffset, yOffset, width, height);

        return [NSAttributedString attributedStringWithAttachment:textAttachment];
    }

    return nil;
}

@end


