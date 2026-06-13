#ifndef REPLIES_HPP
#define REPLIES_HPP

// ============================================================
// RPL — Respuestas de registro y bienvenida
// ============================================================
#define RPL_WELCOME             1   // :Welcome to the network <nick>
#define RPL_YOURHOST            2   // :Your host is <server>, running version <ver>
#define RPL_CREATED             3   // :This server was created <date>
#define RPL_MYINFO              4   // <server> <version> <usermodes> <chanmodes>

// ============================================================
// RPL — MOTD (Message of the Day)
// ============================================================
#define RPL_MOTDSTART           375 // :- <server> Message of the day -
#define RPL_MOTD                372 // :- <text>
#define RPL_ENDOFMOTD           376 // :End of MOTD command

// ============================================================
// RPL — NICK
// ============================================================
#define RPL_NICKLIST            353 // = <channel> :<nicks>  (NAMES reply)
#define RPL_ENDOFNAMES          366 // <channel> :End of NAMES list

// ============================================================
// RPL — JOIN / canal
// ============================================================
#define RPL_TOPIC               332 // <channel> :<topic>
#define RPL_NOTOPIC             331 // <channel> :No topic is set
#define RPL_INVITING            341 // <channel> <nick>

// ============================================================
// RPL — MODE
// ============================================================
#define RPL_UMODEIS             221 // <user mode string>
#define RPL_CHANNELMODEIS       324 // <channel> <mode> <mode params>

// ============================================================
// RPL — WHO / WHOIS
// ============================================================
#define RPL_WHOISUSER           311 // <nick> <user> <host> * :<realname>
#define RPL_WHOISSERVER         312 // <nick> <server> :<serverinfo>
#define RPL_ENDOFWHOIS          318 // <nick> :End of WHOIS list
#define RPL_WHOISCHANNELS       319 // <nick> :<channels>

// ============================================================
// ERR — Registro
// ============================================================
#define ERR_NONICKNAMEGIVEN     431 // :No nickname given
#define ERR_ERRONEUSNICKNAME    432 // <nick> :Erroneous nickname
#define ERR_NICKNAMEINUSE       433 // <nick> :Nickname is already in use
#define ERR_NEEDMOREPARAMS      461 // <command> :Not enough parameters
#define ERR_ALREADYREGISTRED    462 // :Unauthorized command (already registered)
#define ERR_PASSWDMISMATCH      464 // :Password incorrect

// ============================================================
// ERR — Canal
// ============================================================
#define ERR_NOSUCHCHANNEL       403 // <channel> :No such channel
#define ERR_TOOMANYCHANNELS     405 // <channel> :You have joined too many channels
#define ERR_BADCHANNELKEY       475 // <channel> :Cannot join channel (+k)
#define ERR_CHANNELISFULL       471 // <channel> :Cannot join channel (+l)
#define ERR_INVITEONLYCHAN      473 // <channel> :Cannot join channel (+i)
#define ERR_BANNEDFROMCHAN      474 // <channel> :Cannot join channel (+b)
#define ERR_CHANOPRIVSNEEDED    482 // <channel> :You're not channel operator
#define ERR_USERONCHANNEL       443 // <user> <channel> :is already on channel
#define ERR_USERNOTINCHANNEL    441 // <nick> <channel> :They aren't on that channel
#define ERR_NOTONCHANNEL        442 // <channel> :You're not on that channel

// ============================================================
// ERR — Mensajes
// ============================================================
#define ERR_NOSUCHNICK          401 // <nick> :No such nick/channel
#define ERR_NORECIPIENT         411 // :No recipient given (<command>)
#define ERR_NOTEXTTOSEND        412 // :No text to send
#define ERR_CANNOTSENDTOCHAN    404 // <channel> :Cannot send to channel

// ============================================================
// ERR — Permisos generales
// ============================================================
#define ERR_UNKNOWNCOMMAND      421 // <command> :Unknown command
#define ERR_NOTREGISTERED       451 // :You have not registered
#define ERR_NOPRIVILEGES        481 // :Permission Denied

#endif // REPLIES_HPP