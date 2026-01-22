import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Resend } from 'resend';
import { CreateContactDto } from './dto/create-contact.dto';

@Injectable()
export class ContactFormService {
  private readonly logger = new Logger(ContactFormService.name);
  private readonly resend: Resend;
  private readonly toEmail: string;
  private readonly fromEmail: string;

  constructor(private readonly configService: ConfigService) {
    const apiKey = this.configService.get<string>('RESEND_API_KEY');
    if (!apiKey) {
      this.logger.warn('RESEND_API_KEY not configured - contact form will not send emails');
    }
    this.resend = new Resend(apiKey);

    this.toEmail = this.configService.get<string>('CONTACT_FORM_TO') || 'david+contact@davidshaevel.com';
    this.fromEmail = this.configService.get<string>('CONTACT_FORM_FROM') || 'david+noreply@davidshaevel.com';
  }

  async sendContactEmail(dto: CreateContactDto): Promise<{ success: boolean; messageId?: string }> {
    this.logger.log(`Processing contact form submission from ${dto.email}`);

    try {
      const { data, error } = await this.resend.emails.send({
        from: this.fromEmail,
        to: this.toEmail,
        replyTo: dto.email,
        subject: `[Contact Form] ${dto.subject}`,
        html: this.buildEmailHtml(dto),
        text: this.buildEmailText(dto),
      });

      if (error) {
        this.logger.error(`Resend API error: ${error.message}`, error);
        throw new ServiceUnavailableException('Failed to send email. Please try again later.');
      }

      this.logger.log(`Contact form email sent successfully. Message ID: ${data?.id}`);
      return { success: true, messageId: data?.id };
    } catch (error) {
      if (error instanceof ServiceUnavailableException) {
        throw error;
      }
      this.logger.error('Unexpected error sending contact form email', error);
      throw new ServiceUnavailableException('Failed to send email. Please try again later.');
    }
  }

  private buildEmailHtml(dto: CreateContactDto): string {
    return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>New Contact Form Submission</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="color: #18181b; border-bottom: 2px solid #3b82f6; padding-bottom: 10px;">New Contact Form Submission</h1>

  <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
    <tr>
      <td style="padding: 10px 0; border-bottom: 1px solid #e4e4e7; font-weight: bold; width: 100px;">Name:</td>
      <td style="padding: 10px 0; border-bottom: 1px solid #e4e4e7;">${this.escapeHtml(dto.name)}</td>
    </tr>
    <tr>
      <td style="padding: 10px 0; border-bottom: 1px solid #e4e4e7; font-weight: bold;">Email:</td>
      <td style="padding: 10px 0; border-bottom: 1px solid #e4e4e7;">
        <a href="mailto:${this.escapeHtml(dto.email)}" style="color: #3b82f6;">${this.escapeHtml(dto.email)}</a>
      </td>
    </tr>
    <tr>
      <td style="padding: 10px 0; border-bottom: 1px solid #e4e4e7; font-weight: bold;">Subject:</td>
      <td style="padding: 10px 0; border-bottom: 1px solid #e4e4e7;">${this.escapeHtml(dto.subject)}</td>
    </tr>
  </table>

  <h2 style="color: #18181b; margin-top: 30px;">Message:</h2>
  <div style="background-color: #f4f4f5; padding: 20px; border-radius: 8px; white-space: pre-wrap;">${this.escapeHtml(dto.message)}</div>

  <p style="margin-top: 30px; color: #71717a; font-size: 14px;">
    This message was sent via the contact form at <a href="https://davidshaevel.com/contact" style="color: #3b82f6;">davidshaevel.com</a>
  </p>
</body>
</html>
    `.trim();
  }

  private buildEmailText(dto: CreateContactDto): string {
    return `
New Contact Form Submission
============================

Name: ${dto.name}
Email: ${dto.email}
Subject: ${dto.subject}

Message:
--------
${dto.message}

---
This message was sent via the contact form at davidshaevel.com
    `.trim();
  }

  private escapeHtml(text: string): string {
    const htmlEscapes: Record<string, string> = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;',
    };
    return text.replace(/[&<>"']/g, (char) => htmlEscapes[char]);
  }
}
