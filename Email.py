import smtplib
import ssl
from email.message import EmailMessage

subject = "Health Check Email"
body = "Hello Team,

Kindly find attached the "
sender = "ewiafe@fvt-l.com"
customer = "customeremail" #change to inputs
password = input("Enter a password: ")

message = EmailMessage()
message["From"] = sender
message["To"] = customer
message["Subject"] = subject

html = f"""
<html>
    <body>
        <h1>{subject}</h1>
        <p>{body}</p>
    </body>
</html>
"""

message.add_alternative(html, subtype="html")

context = ssl.create_default_context()

print("Sending Email!")

with smtplib.SMTP_SSL("smtp.gmail.com", 465, context=context) as server:
    server.login(sender, password)
    server.sendmail(sender, customer, message.as_string())

print("Success")