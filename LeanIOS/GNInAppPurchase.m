//
//  GNInAppPurchase.m
//  GoNativeIOS
//
//  Created by Weiyin He on 12/1/16.
//  Copyright © 2016 GoNative.io LLC. All rights reserved.
//

#import "GNInAppPurchase.h"
#import "GoNativeAppConfig.h"
#import "LEANUtilities.h"
#import "LEANRootViewController.h"
#import <StoreKit/StoreKit.h>

@interface GNInAppPurchase() <SKProductsRequestDelegate, WKScriptMessageHandler, WKUIDelegate>
@property SKProductsRequest *productsRequest;
@property BOOL isReady;
@property BOOL canMakePurchases;
@property NSArray *products;
@property WKWebView *wkWebView;
@property BOOL webviewIsAttached;
@property NSURL *postUrl;
@property NSMutableDictionary *pendingTransactions;
@end


@implementation GNInAppPurchase

+ (instancetype)sharedInstance
{
    static GNInAppPurchase *sharedInstance;
    
    @synchronized(self)
    {
        if (!sharedInstance){
            sharedInstance = [[GNInAppPurchase alloc] init];
            
            GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
            if (!appConfig.iapEnabled) return sharedInstance;
            
            sharedInstance.postUrl = appConfig.iapPostUrl;
            
            if (appConfig.useWKWebView) {
                WKWebViewConfiguration *config = [[NSClassFromString(@"WKWebViewConfiguration") alloc] init];
                config.processPool = [LEANUtilities wkProcessPool];
                config.userContentController = [[WKUserContentController alloc] init];
                [config.userContentController addScriptMessageHandler:sharedInstance name:@"GonativeIap"];
                
                sharedInstance.wkWebView = [[NSClassFromString(@"WKWebView") alloc] initWithFrame:CGRectZero configuration:config];
                
                // load url to get around same-origin policy
                [sharedInstance.wkWebView loadHTMLString:@"" baseURL:appConfig.iapPostUrl];
            }
            sharedInstance.webviewIsAttached = NO;
            
            sharedInstance.pendingTransactions = [NSMutableDictionary dictionary];
        }
        return sharedInstance;
    }
}

-(void)initialize
{
    self.isReady = NO;

    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    if (!appConfig.iapEnabled) {
        self.isReady = YES;
        return;
    }
    
    self.canMakePurchases = [SKPaymentQueue canMakePayments];
    if (!self.canMakePurchases) {
        self.isReady = YES;
        return;
    }
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:appConfig.iapProductsUrl completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        BOOL success = NO;
        
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
            if (httpResponse.statusCode == 200) {
                id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([json isKindOfClass:[NSDictionary class]]) {
                    NSArray *productIds = json[@"products"];
                    if ([productIds isKindOfClass:[NSArray class]]) {
                        success = YES;
                        [self checkProductIds:productIds];
                    }
                }
            }
        }
        
        if (!success) {
            self.isReady = YES;
            self.canMakePurchases = NO;
        }
    }];
    [task resume];
}

-(void)checkProductIds:(NSArray*)productIds
{
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc]
                                          initWithProductIdentifiers:[NSSet setWithArray:productIds]];
    self.productsRequest = productsRequest;
    productsRequest.delegate = self;
    [productsRequest start];
}

-(void)getInAppPurchaseInfoWithBlock:(void (^)(NSDictionary *))block
{
    if (!self.isReady) return;
    
    NSMutableArray *products = [NSMutableArray arrayWithCapacity:self.products.count];
    for (SKProduct *product in self.products) {
        // format price
        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
        [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        [numberFormatter setLocale:product.priceLocale];
        NSString *priceFormatted = [numberFormatter stringFromNumber:product.price];
        
        [products addObject:@{
            @"localizedDescription": product.localizedDescription,
            @"localizedTitle": product.localizedTitle,
            @"price": product.price,
            @"priceLocale": product.priceLocale.localeIdentifier,
            @"priceFormatted": priceFormatted,
            @"productID": product.productIdentifier
        }];
    }
    
    block(@{
        @"platform": @"iTunes",
        @"canMakePurchases": [NSNumber numberWithBool:self.canMakePurchases],
        @"products": products
    });
}

-(void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    self.products = response.products;
    for (NSString *invalidProduct in response.invalidProductIdentifiers) {
        NSLog(@"Invalid IAP product: %@", invalidProduct);
    }
    
    self.isReady = YES;
}

-(void)purchaseProduct:(NSString*)productId
{
    SKProduct *product;
    for (SKProduct *p in self.products) {
        if ([p.productIdentifier isEqualToString:productId]) {
            product = p;
            break;
        }
    }
    
    if (!product) {
        NSLog(@"Product not found: %@", productId);
        return;
    }
    
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

-(void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions
{
    for (SKPaymentTransaction *transaction in transactions) {
        if (transaction.transactionState == SKPaymentTransactionStateFailed) {
            if (transaction.error.code == SKErrorPaymentCancelled) {
                continue;
            }
            
            NSLog(@"Payment error: %@", transaction.error);
            [self showAlertWithTitle:@"Error" message:@"There was an error completing your purchase. You have not been charged"];
        }
        else if (transaction.transactionState == SKPaymentTransactionStatePurchased) {
            [self fulfillTransaction:transaction];
        }
    }
}

-(void)fulfillTransaction:(SKPaymentTransaction*)transaction
{
    self.pendingTransactions[transaction.transactionIdentifier] = transaction;
    [self fulfillTransactionId:transaction.transactionIdentifier];
}

-(void)fulfillTransactionId:(NSString*)transactionId
{
    if (!self.webviewIsAttached) {
        UIViewController *rvc = [UIApplication sharedApplication].keyWindow.rootViewController;
        if (rvc) {
            [rvc.view addSubview:self.wkWebView];
        }
    }
    
    // get receipts
    NSURL *receiptUrl = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptUrl];
    NSString *receipt = [receiptData base64EncodedStringWithOptions:0];
    
    NSDictionary *toSend = @{@"receipt-data": receipt};
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:toSend options:0 error:nil];
    
    // if using WkWebView, send POST via WkWebView.
    if (self.wkWebView) {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        
        NSString *js = [NSString stringWithFormat: @"function gonative_run_iap() {\n"
                        "var xhr = new XMLHttpRequest();\n"
                        "xhr.onreadystatechange = function() {\n"
                        "  if (xhr.readyState === XMLHttpRequest.DONE) {\n"
                        "    window.webkit.messageHandlers.GonativeIap.postMessage({status: xhr.status, response: xhr.response, transactionId: %@});\n"
                        "  }\n"
                        "};"
                        "xhr.open('POST', %@, true);\n"
                        "xhr.setRequestHeader('Content-Type', 'application/json; charset=UTF-8');\n"
                        "xhr.send(%@);"
                        "}\n"
                        "gonative_run_iap()",
                        [LEANUtilities jsWrapString:transactionId],
                        [LEANUtilities jsWrapString:[self.postUrl absoluteString]],
                        [LEANUtilities jsWrapString:jsonString]];
        [self.wkWebView evaluateJavaScript:js completionHandler:nil];
        return;
    } else {
        // do POST directly
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.postUrl];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [request setHTTPBody:jsonData];
        
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error posting to %@", self.postUrl);
                return;
            }
            
            [self receivedJSONResponse:data forTransaction:transactionId];
        }];
        
        [task resume];
    }
}

-(void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    if (![message.body isKindOfClass:[NSDictionary class]]) {
        NSLog(@"Message.body is not a dictionary. Instead it is %@", [message.body class]);
        return;
    }
    
    NSNumber *status = message.body[@"status"];
    if (![status isKindOfClass:[NSNumber class]]) {
        NSLog(@"Message.body.status is not a number");
        return;
    }

    if ([status isEqualToNumber:@0]) {
        NSLog(@"In-app purchase POST failed");
        return;
    }
    
    NSString *response = message.body[@"response"];
    if (![response isKindOfClass:[NSString class]]) {
        NSLog(@"Response is not a string");
        return;
    }
    
    NSString *transactionId = message.body[@"transactionId"];
    [self receivedJSONResponse:[response dataUsingEncoding:NSUTF8StringEncoding] forTransaction:transactionId];
}

-(void)receivedJSONResponse:(NSData*)response forTransaction:(NSString*)transactionId
{
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:response options:0 error:nil];
    if (![json isKindOfClass:[NSDictionary class]]) {
        NSLog(@"Response is not a serialized JSON object");
        return;
    }
    
    NSString *showMessage = json[@"message"];
    NSString *showTitle = json[@"title"];
    
    if ([showMessage isKindOfClass:[NSString class]]) {
        if (![showTitle isKindOfClass:[NSString class]]) {
            showTitle = @"";
        }
        [self showAlertWithTitle:showTitle message:showMessage];
    }
    
    NSString *loadUrl = json[@"loadUrl"];
    if ([loadUrl isKindOfClass:[NSString class]] && loadUrl.length > 0) {
        UIViewController *rvc = [UIApplication sharedApplication].keyWindow.rootViewController;
        if ([rvc isKindOfClass:[LEANRootViewController class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(LEANRootViewController*)rvc loadUrl:[NSURL URLWithString:loadUrl]];
            });
        }
    }
    
    NSNumber *success = json[@"success"];
    if ([success isKindOfClass:[NSNumber class]] && [success boolValue] &&
        [transactionId isKindOfClass:[NSString class]]) {
        [self markTransactionComplete:transactionId];
    }

}

-(void)markTransactionComplete:(NSString*)transactionId
{
    if (!transactionId) return;
    
    SKPaymentTransaction *transaction = self.pendingTransactions[transactionId];
    if (transaction) {
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        NSLog(@"In-app purchase complete: %@", transaction.payment.productIdentifier);
        [self.pendingTransactions removeObjectForKey:transactionId];
    } else {
        NSLog(@"Could not find transaction to mark complete: %@", transactionId);
    }
}

-(void)showAlertWithTitle:(NSString*)title message:(NSString*)message
{
    if (!title) title = @"";
    if (!message || message.length == 0) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        }];
        [alert addAction:action];
        
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}
@end
