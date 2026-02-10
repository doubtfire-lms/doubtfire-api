#include "splashkit.h"

void simple_print(string message)
{
    write_line("Message: " + message);
}
void title_print(string message)
{
    write_line("====" + to_uppercase(message) + "====");
}
void strange_print(string message)
{
    string lowercase = to_lowercase(message);

    write("~");
    for(int i = 0; i < lowercase.size(); i ++)
    {

        write(lowercase[i]);
        write("~");
    }

    write_line();
}

void print_messages(void (*func)(string))
{
    func("Hello!");
    func("Another message!");
    func("Function pointers are fun!");
    func("Hopefully!");
}

int main()
{
    print_messages(simple_print);
    print_messages(title_print);
    print_messages(strange_print);
    int* x = new int();
    delete x;
}
