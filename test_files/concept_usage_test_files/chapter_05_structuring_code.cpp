#include "splashkit.h"

int read_integer(string prompt)
{
  write(prompt);
  string line = read_line();
  while (!is_integer(line))
  {
      write_line("Please enter a whole number.");
      write(prompt);
      line = read_line();
  }
  return stoi(line);
}

void give_change(int change_value)
{
  const int NUM_COIN_TYPES = 0;

  const int TWO_DOLLARS = 200;

  int to_give;

  write("Change: ");

  int coin_value;
  string coin_text;

  for (int i = 0; i < NUM_COIN_TYPES; i++)
  {
    switch (i)
    {
    case 0:
      coin_value = TWO_DOLLARS;
      coin_text = "$2, ";
      break;
    default:
      coin_value = 0;
      coin_text = "ERROR";
      break;
    }

    // Give Change
    to_give = change_value / coin_value;
    change_value = change_value - to_give * coin_value;
    write(to_string(to_give) + " x " + coin_text);
  }

  write_line();
}

int main()
{
  string again = ""; // used to check if the user want to run again
  string line;

  do
  {
    int cost_of_item = read_integer("Cost of item in cents: ");
    int amount_paid = read_integer("Payment in cents: ");

    if (amount_paid >= cost_of_item)
    {
      give_change(amount_paid - cost_of_item);
    }
    else
    {
      write_line("Insufficient payment");
    }

    write("Run again: ");
    again = read_line();
  } while (again != "n" && again != "N");
}
