import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  // User's provided App Password
  static const String _appPassword = 'vtue tmut scei jksf';
  
  // TODO: Put your actual Gmail address here
  static const String _emailAddress = 'adamriggs.mendoza@neu.edu.ph'; 

  static Future<bool> sendEmail({
    required String toEmail,
    required String subject,
    required String messageText,
  }) async {
    try {
      if (_emailAddress.contains('YOUR_GMAIL_ADDRESS')) {
        // Fallback mock if the user hasn't put their email yet
        print('MOCK EMAIL: To $toEmail | Subject: $subject | Msg: $messageText');
        return true; 
      }

      // Configure Gmail SMTP Server
      final smtpServer = gmail(_emailAddress, _appPassword);

      // Create email message
      final message = Message()
        ..from = const Address(_emailAddress, 'Academic System Notifier')
        ..recipients.add(toEmail)
        ..subject = subject
        ..html = _buildHtmlContent(subject, messageText);

      // Send email
      final sendReport = await send(message, smtpServer);
      print('Message sent: ${sendReport.toString()}');
      return true;
    } on MailerException catch (e) {
      print('Message not sent. \n${e.toString()}');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
      return false;
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }

  static String _buildHtmlContent(String subject, String messageText) {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: #f4f7f6;
            margin: 0;
            padding: 0;
          }
          .container {
            max-width: 600px;
            margin: 40px auto;
            background-color: #ffffff;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 4px 15px rgba(0,0,0,0.05);
            border: 1px solid #eaeaea;
          }
          .header {
            background-color: #1664C5;
            color: #ffffff;
            padding: 24px;
            text-align: center;
          }
          .header h2 {
            margin: 0;
            font-size: 20px;
            font-weight: 600;
            letter-spacing: 0.5px;
          }
          .content {
            padding: 32px 24px;
            color: #333333;
            line-height: 1.6;
            font-size: 15px;
          }
          .content p {
            margin-bottom: 20px;
          }
          .footer {
            background-color: #fafafa;
            padding: 16px 24px;
            text-align: center;
            color: #888888;
            font-size: 12px;
            border-top: 1px solid #eeeeee;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h2>Academic System Notification</h2>
          </div>
          <div class="content">
            <h3 style="color: #224A60; margin-top: 0;">Subject: $subject</h3>
            <p>${messageText.replaceAll('\n', '<br>')}</p>
            <br>
            <p>Best regards,<br><strong>Your Academic System Team</strong></p>
          </div>
          <div class="footer">
            <p>This is an automated message. Please do not reply directly to this email.</p>
            <p>&copy; ${DateTime.now().year} Academic System. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    ''';
  }
}
