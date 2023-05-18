# Reborn

A library forked and inspired by Alfred to build fast and simple dart http servers with multi-method and multi-path support in ExpressJS way.

## Get Started

Create a new instance of *RebornApp*, use *request* method to add new endpoints and call *listen* when you're ready with your handlers.

Reborn doesn't provide specific methods for http methods, besides that, provides a generic request method for adding multi-method endpoints as you wish.

    void main() async {
        final app = RebornApp(pathPrefix: 'api/v1');

        app.request(['test', 'testpost'], (req, res) async {
            final body = await req.body;

            return jsonEncode(Test(1, 'test', body != null).toJson());
        }, supportedMethods: [Method.post, Method.put]);

        await app.listen(port: 7070, bindIp: '127.0.0.1');
    }

## Status

This library is a work in progress and should not be used in production right now.

## Todo

- Tests
- Logging
- Docs
- More examples

