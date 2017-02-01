#!/usr/bin/python

#Send an email message from the user's account.


import base64
from email.mime.audio import MIMEAudio
from email.mime.base import MIMEBase
from email.mime.image import MIMEImage
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import mimetypes
import os

#from __future__ import print_function
import httplib2
import os

from apiclient import discovery
import oauth2client
from oauth2client import client
from oauth2client import tools

from apiclient import errors

SCOPES = 'https://www.googleapis.com/auth/gmail.compose'
CLIENT_SECRET_FILE = 'client_secret.json'
APPLICATION_NAME = 'Gmail API Send Email'

#this function will get user credentials for google api
def get_credentials():
    #defining the home directory
    home_dir = os.path.expanduser('~')
    #credential_dir path will be ~/.credentials (hidden directory for the creds)
    credential_dir = os.path.join(home_dir, '.credentials')
    #if ~/.credentials does not exist create the directory
    if os.path.exists(credential_dir) == False:
        print "creating director %s" % (credential_dir)
        os.makedirs(credential_dir)
    else:
        print "directory %s does exists" % (credential_dir)
    credential_path = os.path.join(credential_dir, 'sendEmail.json')
    #storing the credentials to ~/.credentials/sendEmail.json
    store = oauth2client.file.Storage(credential_path)
    #gets the stored cred file
    credentials = store.get()

    #if the credentials file does not exist, will use the client_secret.json file to generate a new one
    if credentials == None:
        flow = client.flow_from_clientsecrets(CLIENT_SECRET_FILE, SCOPES)
        flow.user_agent = APPLICATION_NAME
        credentials = tools.run_flow(flow, store)
        print "storing credentials to %s" % (credential_path)
    return credentials

#this function will create the actual message for the email
def CreateMessage(sender, to, subject, message_text):
  message = MIMEText(message_text)
  message['to'] = to
  message['from'] = sender
  message['subject'] = subject
  return {'raw': base64.urlsafe_b64encode(message.as_string())}

def SendMessage(service, user_id, message):
    #user_id: User's email address. The special value "me" can be used to indicate the authenticated user.
    message = (service.users().messages().send(userId=user_id, body=message)
               .execute())
    print 'Message Id: %s' % message['id']
    return message
#get the api creds
credentials = get_credentials()
#authorize creds using the stored cred json file which has the url
http = credentials.authorize(httplib2.Http())

#discover the google api
service = discovery.build('gmail', 'v1', http=http)

#get the message details
sender = raw_input("Enter your email address: ") 
to = raw_input("Enter the \"To:\" email address: ")
text = "sent by Felicia's %s" % (APPLICATION_NAME)
subject = "Message from Felicia's GMAIL API"

#create the message
message = CreateMessage(sender, to, subject, text)

#send the message
SendMessage(service, "me", message)
