.intel_syntax noprefix
.global _start

.section .text

_start:
    sub rsp, 0x5000   # allocate some space
socket:
    mov rax, 41		# socket(2)
    mov rdi, 2		# AF_INET for IPV4
    mov rsi, 1		# SOCK_STREAM for tcp
    xor rdx, rdx 	# OS selects tcp when arg3 is 0
    syscall
    mov rbx, rax	
bind:
    mov rdi, rax	# use the socket fd
    mov rax, 49 	# bind(2)
    mov rdx, 16 	# addrlen field

    mov WORD PTR [rsp], 0x0002 # AF_INET
    mov WORD PTR [rsp+2], 0x5000 # port 80
    mov DWORD PTR [rsp+4], 0x0 # 0.0.0.0
    mov QWORD PTR [rsp+8], 0x0 # padding

    mov rsi, rsp 
    syscall
listen:
    mov rax, 50 	# listen(2)
    mov rdi, rbx	# socket fd
    mov rsi, 128	# 128 backlog for simplicity  
    syscall
ignore_sigchld:
    mov rax, 13                 # rt_sigaction(2)
    mov rdi, 17                 # SIGCHLD
    lea rsi, [rip+sigchld_act]  # new action
    xor rdx, rdx                # don't need the old action
    mov r10, 8                  # sizeof(sigset_t), 4th arg goes in r10
    syscall
accept:
    mov rax, 43		# accept(2)
    mov rdi, rbx	# socket fd
    mov rsi, 0 		# accept from anyone
    mov rdx, 0
    syscall
    mov rbp, rax

fork_process:		# fork for concurrency
    mov rax, 57
    syscall
    test rax, rax
    jz child_close_original_socket
parent_close_new_socket: 
    mov rax, 3
    mov rdi, rbp
    syscall
    jmp accept
child_close_original_socket:
    mov rax, 3
    mov rdi, rbx
    syscall

read_request:
    mov rax, 0
    mov rdi, rbp
    lea rsi, [rsp]
    mov rdx, 0x5000 		#read 5000 bytes
    syscall
find_path_init:
    mov rdi, rsp
find_path:
    cmp BYTE PTR [rdi], '/' # find the requested path from the slash
    jz read_path_init
    inc rdi
    jmp find_path
read_path_init:
    mov rcx, rdi
read_path:
    inc rcx
    cmp BYTE PTR [rcx], ' ' 
    jnz read_path
    mov BYTE PTR [rcx], 0 	#null byte to terminate open(2)
request_type:
    cmp DWORD PTR [rsp], 0x20544547 # "GET " but reversed for endianness
    jnz POST_find_message_body

GET_open_file: 
    mov rax, 2
    # rdi already contains file path
    mov rsi, 0
    xor rdx, rdx # xor rdx just for the sake of it
    syscall
GET_read_file:
    mov r12, rax
    mov rdi, r12
    mov rax, 0
    lea rsi, [rsp]
    mov rdx, 0x5000
    syscall
    push rax
GET_close_file:
    mov rax, 3
    mov rdi, r12
    syscall
GET_write_response:
    mov rdi, rbp
    mov rax, 1
    lea rsi, [rip+http_response]
    mov rdx, 19
    syscall
    pop rdx
    mov rdi, rbp
    mov rax, 1
    mov rsi, rsp
    syscall
    jmp close_socket

POST_find_message_body:
    # cmp rcx, 
    inc rcx
    cmp DWORD PTR [rcx], 0x0a0d0a0d # \r\n\r\n in little endian
    jnz POST_find_message_body
    add rcx, 4
    mov rsi, rcx
    sub rsi, rsp
    sub rax, rsi
    push rax
    push rcx
POST_open_file:
    mov rax, 2
    # rdi already contains file path
    mov rsi, 01101  # O_WRONLY | O_CREAT | O_TRUNC
    mov rdx, 0644   # commonly used permissions on the created file
    syscall
POST_write_file:
    mov r12, rax
    mov rax, 1
    mov rdi, r12
    pop rsi
    pop rdx
    syscall
POST_close_file:
    mov rax, 3
    mov rdi, r12
    syscall
POST_write_response:
    mov rdi, rbp
    mov rax, 1
    lea rsi, [rip+http_response]
    mov rdx, 19
    syscall
    jmp close_socket

close_socket: 
    mov rax, 3
    mov rdi, rbp
    syscall
exit:
    add rsp, 0x5000
    mov rdi, 0
    mov rax, 60     # SYS_exit
    syscall



.section .rodata

http_response:
    .ascii "HTTP/1.0 200 OK\r\n\r\n"

.balign 8
sigchld_act:
    .quad 1     # sa_handler = SIG_IGN -> kernel auto-reaps children
    .quad 0     # sa_flags
    .quad 0     # sa_restorer
    .quad 0     # sa_mask
