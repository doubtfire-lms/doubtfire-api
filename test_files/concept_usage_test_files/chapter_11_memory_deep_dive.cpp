#include <string>

enum an_enum {

};

template<typename T>
struct ptr
{
    ptr<T>* p;
    T* data;
    ptr()
    {
        p = nullptr;
        data = new T[50];
    }
    ~ptr()
    {
        if (data)
            delete [] data;
    }
};

template<typename T>
void procedure(ptr<T>* p)
{
    ptr<T>* q = p;
    while(q)
    {
        ptr<T>* o = q->p;
        delete q;
        q = o;
    }
}

int main()
{
    ptr<int>* p = new ptr<int>();

    p->p = new ptr<int>();

    procedure(p);

    throw std::string("An exception!");
}
