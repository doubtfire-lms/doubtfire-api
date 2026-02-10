#include "splashkit.h"

struct user_info
{
	string Name;
	string favourite_tv_show;
	string favouriteMeal;

	user_info()
	{
      Name = "N/A";
      favourite_tv_show = "N/A";
      favouriteMeal = "N/A";
	}
};

int main()
{
	user_info user;

	write_line("Welcome to the very basic bot experience!");
	write_line("Please answer using single words :)");
	delay(200);
	write_line("----------------------------------------");
	delay(200);
	write_line();

	delay(200);
	write_line("Bot: Hello! What's your name?");
	delay(200);
	write("> ");
	user.Name = read_line();
	write_line("Bot: Hi " + user.Name + ", nice to meet you!");

	delay(200);
	write_line("Bot: What's your favourite TV show?");
	delay(200);
	write("> ");
	user.favourite_tv_show = read_line();
	write_line("Bot: " + to_uppercase(user.favourite_tv_show) + "!? Umm... I don't like " + user.favourite_tv_show + " that much sorry.");

	delay(200);
	write_line("What about food? Favourite meal?");
	delay(200);
	write("> ");
	user.favouriteMeal = read_line();
	write_line("Bot: " + to_lowercase(user.favouriteMeal) + " is a better choice than " + to_lowercase(user.favourite_tv_show) + " at least...");

	delay(600);
	write_line("Anyway bye!");
	delay(200);
	write_line("\nThe bot has left the chat.");

	return 0;
}
