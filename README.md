# ChatServer

## Other features

- Broadcast messages to all clients
- Other chatting features

- TODO: To enhance this with `chattex`

- In progress, handle mentions appropriately, 
- disconnect logic

Notes:

Here all the state is encapsulated in `connection_supervisor.ex` as a GenServer as opposed to `DynamicSupervisor` behavior (which doesn't)

https://www.youtube.com/watch?v=tm4Jgg7zeXk
