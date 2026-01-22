import { Controller, Post, Body, HttpCode, HttpStatus } from '@nestjs/common';
import { ContactFormService } from './contact-form.service';
import { CreateContactDto } from './dto/create-contact.dto';

@Controller('contact')
export class ContactFormController {
  constructor(private readonly contactFormService: ContactFormService) {}

  @Post()
  @HttpCode(HttpStatus.OK)
  async submitContactForm(@Body() createContactDto: CreateContactDto) {
    const result = await this.contactFormService.sendContactEmail(createContactDto);
    return {
      success: result.success,
      message: 'Thank you for your message. I will get back to you soon!',
    };
  }
}
