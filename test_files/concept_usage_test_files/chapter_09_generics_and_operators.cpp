template<typename T>
struct array
{
    T inner[2];

    void do_something()
    {

    }

    int& operator [](int i)
    {
        return inner[i];
    }
};


int main()
{
    array<int> test;
    test.do_something();
}
