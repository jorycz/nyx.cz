//
//  LoginScreenVC.m
//  Nyx.cz
//
//  Created by Josef Rysanek on 15/11/2017.
//  Copyright © 2017 Josef Rysanek. All rights reserved.
//

#import "LoginScreenVC.h"
#import "ApiBuilder.h"
#import "JSONParser.h"
#import "Constants.h"
#import "Preferences.h"
#import "Colors.h"


@interface LoginScreenVC ()

@end

@implementation LoginScreenVC

- (void)loadView
{
    [super loadView];
    self.view = [[UIView alloc] init];
    self.view.backgroundColor = COLOR_BACKGROUND_WHITE;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.userIsLoggedIn = NO;
        _firstShow = YES;
        _auth_code = [[NSMutableString alloc] initWithCapacity:128];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _logoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"logo"]];
    _logoView.userInteractionEnabled = NO;
    [_logoView setContentMode:(UIViewContentModeCenter)];
    [self.view addSubview:_logoView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    // Logout & relogin mess logo position.
    if (_firstShow) {
        _firstShow = NO;
        CGRect _mainFrame = self.view.frame;
        _baseX = _mainFrame.size.width / 4;
        _baseY = _mainFrame.size.height / 14;
        _fWidth = _mainFrame.size.width / 2;
        _fHeight = 190;
        _logoView.frame = CGRectMake(_baseX, 248, _fWidth, _fHeight);
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [UIView animateWithDuration:0.5 animations:^{
        _logoView.frame = CGRectMake(_baseX, _baseY, _fWidth, _fHeight);
    } completion:^(BOOL finished) {
        [self tryToLogIn];
    }];
}

#pragma mark - LOGIN & AUTHORIZATION

- (void)tryToLogIn
{
#if TARGET_OS_SIMULATOR
    NSLog(@"%@ - %@ : [%@]", self, NSStringFromSelector(_cmd), @"Running on SIMULATOR!");
    NSString *pass = [Preferences password:nil];
    if (pass && [pass length] > 0) {
        [self presentNyxScreen];
    } else {
        [self askForUsername];
    }
#else
    NSString *user = [Preferences auth_nick:nil];
    NSString *token = [Preferences auth_token:nil];
    if ([user length] > 0 && [token length] > 0) {
        [self showHideSpinner];
        [self authorizeWithLoginName:user];
    } else {
        [self askForUsername];
    }
#endif
}

- (void)askForUsername
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Autorizace"
                                                                   message:@"Zadej uživatelské jméno."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *login = [UIAlertAction actionWithTitle:@"Získat autorizační kód" style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   [self showHideSpinner];
#if TARGET_OS_SIMULATOR
                                                   NSLog(@"%@ - %@ : [%@]", self, NSStringFromSelector(_cmd), @"Running on SIMULATOR!");
                                                   // SKIP Authorization on SIMULATOR - take care to fill login and password here OK!
                                                   NSString *simulatorUser = [[alert.textFields objectAtIndex:0] text];
                                                   NSString *simulatorPassword = [[alert.textFields objectAtIndex:1] text];
                                                   [Preferences username:simulatorUser];
                                                   [Preferences auth_nick:simulatorUser];
                                                   [Preferences password:simulatorPassword];
                                                   [self presentNyxScreen];
#else
                                                   NSString *user = [[alert.textFields objectAtIndex:0] text];
                                                   [Preferences auth_nick:user];
                                                   [self authorizeWithLoginName:user];
#endif
                                               }];
    [alert addAction:login];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Jméno";
    }];
#if TARGET_OS_SIMULATOR
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Heslo";
    }];
#endif
    [self presentViewController:alert animated:YES completion:^{}];
}

- (void)authorizeWithLoginName:(NSString *)auth_user
{
    if ([auth_user length] < 1) {
        [self presentErrorWithTitle:@"Chyba" andMessage:@"Uživatelské jméno nesmí být prázdné."];
        return;
    }
    self.sc = [[ServerConnector alloc] init];
    self.sc.delegate = self;
    NSString *api = [ApiBuilder apiAuthorizeForUser:auth_user];
    [self.sc downloadDataForApiRequest:api];
}

- (void)downloadFinishedWithData:(NSData *)data withIdentification:(NSString *)identification
{
    if (!data)
    {
        [self presentErrorWithTitle:@"Žádná data" andMessage:@"Nelze se připojit na server."];
    }
    else
    {
        JSONParser *jp = [[JSONParser alloc] initWithData:data];
        if (!jp.jsonDictionary)
        {
            NSLog(@"%@ - %@ : ERROR [%@]", self, NSStringFromSelector(_cmd), jp.jsonErrorString);
            NSLog(@"%@ - %@ : ERROR [%@]", self, NSStringFromSelector(_cmd), jp.jsonErrorDataString);
            [self presentErrorWithTitle:@"Chyba při parsování" andMessage:jp.jsonErrorString];
        }
        else
        {
//            NSLog(@"%@ - %@ : [%@]", self, NSStringFromSelector(_cmd), jp.jsonDictionary);
            if ([[jp.jsonDictionary objectForKey:@"result"] isEqualToString:@"error"])
            {
                if ([[jp.jsonDictionary objectForKey:@"code"] isEqualToString:@"401"]) {
                    // App is not authorized.
                    if ([[jp.jsonDictionary objectForKey:@"auth_state"] isEqualToString:@"AUTH_EXISTING"]) {
                        // Tell user that they need to cancel authorization on web.
                        [self authorizationExistCancelExistingFirst];
                    } else {
                        [Preferences auth_token:[jp.jsonDictionary objectForKey:@"auth_token"]];
                        [_auth_code setString:[jp.jsonDictionary objectForKey:@"auth_code"]];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self showActivationOrChangeNickAlert];
                        });
                    }
                } else {
                    [self presentErrorWithTitle:@"Chyba ze serveru:" andMessage:[jp.jsonDictionary objectForKey:@"error"]];
                }
            }
            else
            {
//                NSLog(@"%@ - %@ : [%@]", self, NSStringFromSelector(_cmd), jp.jsonDictionary);
                [self presentNyxScreen];
            }
        }
    }
}

- (void)showActivationOrChangeNickAlert
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = _auth_code;
    NSURL *authUrl = [NSURL URLWithString:@"https://www.nyx.cz/index.php?l=user;l2=2;section=authorizations"];
    NSString *message = [NSString stringWithFormat:@"Zadejte autorizační kód %@ do svého účtu na www.nyx.cz do sekce OSOBNÍ / NASTAVENÍ / AUTORIZACE.\n\nTento kód je nyní uložen ve schránce a stačí jej vložit do nastavení a následně uložit nastavení na webu po přihlášení na NYX do příslušné sekce, která se otevře v prohlížeči po kliknutí na tlačítko Přihlásit na Nyx.", _auth_code];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Autorizační kód"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *login = [UIAlertAction actionWithTitle:@"Přihlásit na Nyx"
                                                    style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                                        [[UIApplication sharedApplication] openURL:authUrl options:@{} completionHandler:^(BOOL success) {
                                                            [[NSNotificationCenter defaultCenter] addObserver:self
                                                                                                     selector:@selector(returnOfTheJedi)
                                                                                                         name:UIApplicationDidBecomeActiveNotification
                                                                                                       object:nil];
                                                        }];
                                                    }];
    UIAlertAction *startAgain = [UIAlertAction actionWithTitle:@"Smazat Nick a začít znova"
                                                         style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                                                             [Preferences auth_nick:@""];
                                                             [Preferences auth_token:@""];
                                                             [self tryToLogIn];
                                                         }];
    [alert addAction:login];
    [alert addAction:startAgain];
    [self presentViewController:alert animated:YES completion:^{}];
}

- (void)returnOfTheJedi
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self tryToLogIn];
}

- (void)authorizationExistCancelExistingFirst
{
    NSString *message = @"Existující autorizace pro toto zařízení a aplikaci již existuje. Pro vytvoření nové autorizace je nejdříve potřeba starou smazat z webu www.nyx.cz sekce OSOBNÍ / NASTAVENÍ / AUTORIZACE.";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Nalezena existující autorizace!"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *startAgain = [UIAlertAction actionWithTitle:@"Začít znova"
                                                         style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                                                             [Preferences auth_nick:@""];
                                                             [Preferences auth_token:@""];
                                                             [self tryToLogIn];
                                                         }];
    [alert addAction:startAgain];
    [self presentViewController:alert animated:YES completion:^{}];
}

#pragma mark - RESULT

- (void)presentErrorWithTitle:(NSString *)title andMessage:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground)
        {
            [self showHideSpinner];
            [self performSelector:@selector(tryToLogIn) withObject:nil afterDelay:3];
        }
        else
        {
            [self showHideSpinner];
            PRESENT_ERROR(title, message)
            
            UIAlertController *a = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:(UIAlertControllerStyleAlert)];
            UIAlertAction *ok = [UIAlertAction actionWithTitle:@"Zkusit znova" style:(UIAlertActionStyleDefault) handler:^(UIAlertAction * _Nonnull action) {
                [self tryToLogIn];
            }];
            [a addAction:ok];
            [self presentViewController:a animated:YES completion:^{}];
        }
    });
}

- (void)presentNyxScreen
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.userIsLoggedIn = YES;
        [self showHideSpinner];
        [self dismissViewControllerAnimated:NO completion:^{}];
    });
}

#pragma mark - SPINNER

- (void)showHideSpinner
{
    if (!self.spinner) {
        self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyleGray)];
        [self.view addSubview:self.spinner];
        [self.spinner startAnimating];
        self.spinner.center = self.view.center;
    } else {
        [self.spinner stopAnimating];
        self.spinner = nil;
    }
}

@end



