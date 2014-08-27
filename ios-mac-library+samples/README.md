Fleep Reader
============

Fleep Reader is a simple RSS/Atom client for Fleep users. It is intended for the "push" or "I want to be notified when an article is posted in a feed that is updated rarely" usecase of RSS syndication.

Reader is written as a MacOS daemon program, using Fleep's official iPhone/Mac API library. It uses Core Data for local data storage and should be efficient enough to support a sizable number of feeds and users without requiring significant resources from the hosting computer.

Using Fleep Reader
------------------
There are two ways of subscribing to a feed using Fleep Reader:

1. Create a new conversation with Reader and say "subscribe <feed url>". If the feed is valid, Reader will respond by creating a new conversation with the name of the feed, and post 10 of the most recent items in the feed. When a new item appears in the feed, it is automatically posted to the conversation.

2. To add several feeds at a time, you can post an OPML file (exported from another RSS reader) to a conversation with Reader. You will be subscribed to all valid feeds in the file.

To unsubscribe from a feed, just say "unsubscribe" in the feed's conversation.

Reader checks all feeds every three hours. If a feed fails to return a valid response five times in a row, all subscribers of that feed are automatically unsubscribed.

Setting up Fleep Reader
-----------------------

Reader has no external dependencies and should compile out of the box with XCode 5.1.

You will need a Fleep account for Reader. The following example assumes you have registered and will be running Reader as "flr@mydomain.com" and the password for the account is "s3cretP4ssw0rd".

To set up Fleep Reader, you first need to log in to its account. Change to folder of the compiled Fleep Reader binary and type:

`./FleepReader login flr@mydomain.com s3cr3tP4ssw0rd`

Fleep Reader will initialize by creating its local repository and synchronizing conversations from Fleep server. It will also create a long term session token allowing subsequent automated logins without having to enter the password again.

To start FleepReader running as a daemon, type:

`nohup ./FleepReader &`

This will start the Fleep Reader process in the background. Fleep Reader is now ready to respond to subscription requests, and will be posting updates when feeds' content change. You can also create a simple Shell script that checks if Fleep Reader is running and starts it if necessary, and add it as a cron job to make sure Reader survives over restart of the computer.

Technical notes
---------------

ReaderApi class (subclass of FLApi) illustrates the interaction between Reader and Fleep servers. To respond to server-side notifications about contacts, conversations, and messages, you override methods in FLApi class. To post messages to conversations, you call methods defined in FLApi+Actions class category.

Reader is not commercial quality software. It is known to fail for some feeds with unusual properties, and it has significant room for improvement in many aspects. We provide the source code of Reader as a real world example of how to use the Fleep API and the Fleep Objective C library.
