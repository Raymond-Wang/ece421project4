Installation Intructions
########################

We're using bundle for dependency management. You can easily install
dependencies with `bundle install'.

Otherwise: 
`gem install dm-mysql-adapter`
`gem install datamapp` should work just fine.
`gem install pry` Is a useful debugger that works in 1.9.3.

Testing
#######

The one test case that I know passes and made it through to the end is
servertest.rb

Old tests are likely to be failing

Executing
#########

Use runserver.rb to run the server.
For the clients, select the network checkbox then use the game for the player.

For design by contract use `export RUBY_CONTRACTS=1`.

Not Implemented
###############

Restore - though it's likely not far off at this point. The individual turns
essentially reload state completely anyway. The restore functionality requires
would require some changes to how the current player is detected. There's also
assumptions such as reset the game when you first start playing.

Single player is likely completely broken.

Other Notes
###########

There's a simple contracts module in contract.rb that uses blocks to wrap
preconditions and postconditions and re-raise any exceptions that occur
as post/pre condition errors. They're only enabled if an environment variable
is set which I thought was a simple way to keep them from crashing in
production. I think one of our assignments actually had a bug that would only
really manifest itself because of a precondition check. Sometimes it's better
to sweep it under the carpet - though my preconditions where an extremely
useful debugging tool :)

Not exactly happy with how this turned out. I just went through a week from
hell that involved staying away 40 hours at the University to complete 1 Lab,
2 Lab reports, 2 large programming assignments, a presentation report. And the
weather sucked.

Post Mortem
###########

I think it could use a couple days of cleanup. There are a bunch of files in
the folder that don't belong. Really, I'm sure the only thing that kind of
works is the single flow I described in "executing" but that's what took the
brunt of the work. In particular, a deadlock issue that I stupidly tried to
solve by panicking with mutexes that only made things worse for 8 hours - it
turned out that the XMLRPC function `call2_async` doesn't actually call things
asynchronously. So the client would call the server and block in a variety of
wierd ways.

Other issues were wrestling with the gui. Simple things like `how do I get the
currently selected item in a list` took an hour each to figure out at times.
I wrestled with how to make a dialog box show up in front of other windows. The
present function works in some cases, doesn't work in others. Dialogs need to
have `run` and `destroy' called on them to show up.

Mutexes. I'm sure I abuse them but I feel I understand what's going on more
than the code will likely demonstrate. Part of the issue is also knowing
whether your API calls spawn their own threads. There's some code with a queue
that gets pushed and popped in order to make sure the connection to the
"server" is established that took a bunch of fiddling with to create. I kept
looking for solutions that didn't involve locking mechanisms because it didn't
feel right to create a single instance variable named `q` for the purpose
like I was looking for the callback functions and events I'm used to ;)

The use of the ORM I think was a mistake in retrospect. I also thing grafting
the functionality on the existing model was a mistake as that was pretty much
solved and working.
