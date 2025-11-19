# rAthena Chat System Analysis

This document provides a comprehensive analysis of the chat system implementation in rAthena, extracted from the rAthena source code.

## Overview

The rAthena chat system supports multiple chat channels with different scopes and visibility rules. Messages are validated, sanitized, and broadcast to appropriate recipients based on the chat type.

## Constants

```c
#define NAME_LENGTH (23 + 1)        // 24 bytes for character names
#define CHAT_SIZE_MAX (255 + 1)     // 256 bytes maximum message size
```

## Chat Types

### 1. Normal/Public Chat
- **Scope**: Area-based (visible to nearby players)
- **Client Packet**: `0x008c` (CZ_REQUEST_CHAT)
- **Server Packet**: `0x008d` (ZC_NOTIFY_CHAT)
- **Handler**: `clif_parse_GlobalMessage`

### 2. Whisper/Private Message
- **Scope**: Direct player-to-player
- **Client Packet**: `0x0096` (CZ_WHISPER)
- **Server Packet**: `0x0097` (ZC_WHISPER)
- **Acknowledgment**: `0x0098` (ZC_ACK_WHISPER)
- **Handler**: `clif_parse_WisMessage`

### 3. Party Chat
- **Scope**: All party members
- **Client Packet**: `0x0108` (CZ_REQUEST_CHAT_PARTY)
- **Server Packet**: `0x0109` (ZC_NOTIFY_CHAT_PARTY)
- **Handler**: `clif_parse_PartyMessage`

### 4. Guild Chat
- **Scope**: All guild members
- **Client Packet**: `0x017e` (CZ_GUILD_CHAT)
- **Server Packet**: `0x017f` (ZC_GUILD_CHAT)
- **Handler**: `clif_parse_GuildMessage`

### 5. Battleground Chat
- **Scope**: Battleground team members
- **Client Packet**: `0x02db` (CZ_BATTLEFIELD_CHAT)
- **Handler**: `clif_parse_BattleChat`

### 6. Clan Chat
- **Scope**: All clan members
- **Client Packet**: `0x098d` (CZ_CLAN_CHAT)
- **Server Packet**: `0x098e` (ZC_NOTIFY_CLAN_CHAT)
- **Handler**: `clif_parse_clan_chat`

## Packet Structures

### Client to Server Packets

#### Normal Chat (0x008c)
```c
// CZ_REQUEST_CHAT
// Format: <packet id>.W <packet len>.W (<name> : <message>).?B
// Variable length packet
// Message format: "CharName : Message text"
```

#### Whisper (0x0096)
```c
// CZ_WHISPER
// Format: <packet id>.W <packet len>.W <nick>.24B <message>.?B
struct {
    int16 PacketType;      // 0x0096
    int16 PacketLength;    // Variable
    char target[24];       // Target player name (NAME_LENGTH)
    char message[];        // Message content
} __attribute__((packed));
```

### Server to Client Packets

#### Normal Chat Broadcast (0x008d - ZC_NOTIFY_CHAT)
```c
struct PACKET_ZC_NOTIFY_CHAT {
    int16 PacketType;      // 0x008d
    int16 PacketLength;    // Variable
    uint32 GID;            // Game ID of the speaker
    char Message[];        // "CharName : Message text"
} __attribute__((packed));
```

#### Player Chat (0x008e - ZC_NOTIFY_PLAYERCHAT)
```c
struct PACKET_ZC_NOTIFY_PLAYERCHAT {
    int16 PacketType;      // 0x008e
    int16 PacketLength;    // Variable
    char Message[];        // Message content only
} __attribute__((packed));
```

#### Whisper (0x0097 - ZC_WHISPER)
```c
// Different structures based on PACKETVER

// Modern version (PACKETVER >= 20131204)
struct PACKET_ZC_WHISPER {
    int16 PacketType;      // 0x0097 or 0x09de
    int16 PacketLength;    // Variable
    uint32 senderGID;      // Sender's Game ID (newer versions)
    char sender[24];       // Sender name (NAME_LENGTH)
    uint8 isAdmin;         // Admin flag (some versions)
    char message[];        // Message content
} __attribute__((packed));

// Older version
struct PACKET_ZC_WHISPER {
    int16 PacketType;
    int16 PacketLength;
    char sender[24];
    int32 isAdmin;         // int32 instead of uint8
    char message[];
} __attribute__((packed));

// Newest version
struct PACKET_ZC_WHISPER {
    int16 PacketType;
    int16 PacketLength;
    char sender[24];
    char message[];        // No admin flag
} __attribute__((packed));
```

#### Whisper Acknowledgment (0x0098 - ZC_ACK_WHISPER)
```c
struct PACKET_ZC_ACK_WHISPER {
    int16 packetType;      // 0x0098 or 0x09df
    uint8 result;          // Result code
    // 0x09df version also includes: uint32 CID;
} __attribute__((packed));

// Whisper result codes
enum e_ack_whisper {
    ACKWHISPER_TARGET_OFFLINE = 0,
    ACKWHISPER_SUCCESS = 1,
    ACKWHISPER_ALL_IGNORED = 2,
    ACKWHISPER_SELF_IGNORED = 3
};
```

#### Party Chat (0x0109 - ZC_NOTIFY_CHAT_PARTY)
```c
struct PACKET_ZC_NOTIFY_CHAT_PARTY {
    int16 PacketType;      // 0x0109
    int16 PacketLength;    // Variable
    int AID;               // Account ID
    char chatMsg[];        // Message content
} __attribute__((packed));
```

#### Guild Chat (0x017f - ZC_GUILD_CHAT)
```c
struct PACKET_ZC_GUILD_CHAT {
    int16 packetType;      // 0x017f
    int16 packetLength;    // Variable
    char message[];        // Message content
} __attribute__((packed));
```

#### Clan Chat (ZC_NOTIFY_CLAN_CHAT)
```c
struct PACKET_ZC_NOTIFY_CLAN_CHAT {
    int16 PacketType;
    int16 PacketLength;
    // Structure details similar to other chat packets
    char message[];
} __attribute__((packed));
```

## Message Flow

### 1. Normal Chat Flow

```
Client                    Map Server                  Other Clients
  |                            |                             |
  |--[0x008c: "Name : Msg"]-->|                             |
  |                            |                             |
  |                            |--[Validate message]         |
  |                            |--[Check permissions]        |
  |                            |--[Check channel binding]    |
  |                            |                             |
  |                            |--[0x008d: GID + "Name : Msg"]-->
  |<--[0x008d: GID + "Name : Msg"]                          |
  |                            |                             |
```

**Handler Implementation:**
```c
void clif_parse_GlobalMessage(int32 fd, map_session_data* sd)
{
    char name[NAME_LENGTH], message[CHAT_SIZE_MAX],
         output[CHAT_SIZE_MAX+NAME_LENGTH*2];

    // Validate packet and retrieve name and message
    if (!clif_process_message(sd, false, name, message, output))
        return;

    // Check if player is in a custom channel
    if (sd->gcbind &&
        ((sd->gcbind->opt & CHAN_OPT_CAN_CHAT) ||
         pc_has_permission(sd, PC_PERM_CHANNEL_ADMIN))) {
        channel_send(sd->gcbind, sd, message);
        return;
    }

    // Send message to others in area
    // Use CHAT_WOS if in chatroom, otherwise AREA_CHAT_WOC
    clif_GlobalMessage(*sd, output, sd->chatID ? CHAT_WOS : AREA_CHAT_WOC);
}
```

### 2. Whisper Flow

```
Client A                  Map Server A              Map Server B              Client B
  |                            |                          |                         |
  |--[0x0096: Target, Msg]-->|                          |                         |
  |                            |                          |                         |
  |                            |--[Find target locally]   |                         |
  |                            |                          |                         |
  |                            |--[If not found]--------->|                         |
  |                            |  [Inter-server whisper]  |                         |
  |                            |                          |--[Find target]          |
  |                            |                          |                         |
  |                            |                          |--[0x0097: Sender, Msg]->|
  |                            |<--[Success notification]-|                         |
  |<--[0x0098: Success]-------|                          |                         |
  |                            |                          |                         |
```

**Handler Implementation:**
```c
void clif_parse_WisMessage(int32 fd, map_session_data* sd)
{
    map_session_data* dstsd;
    char target[NAME_LENGTH], message[CHAT_SIZE_MAX],
         output[CHAT_SIZE_MAX+NAME_LENGTH*2];

    // Validate packet and retrieve name and message
    if (!clif_process_message(sd, true, target, message, output))
        return;

    // Chat logging
    log_chat(LOG_CHAT_WHISPER, 0, sd->status.char_id,
             sd->status.account_id, mapindex_id2name(sd->mapindex),
             sd->x, sd->y, target, message);

    // Check for NPC whisper commands
    if (target[0] && (strncasecmp(target, "NPC:", 4) == 0) &&
        (strlen(target) > 4)) {
        // Handle NPC whisper...
        return;
    }

    // Try to find target on same map server
    dstsd = map_nick2sd(target, false);

    if (dstsd == nullptr) {
        // Target not on this map server, use inter-server whisper
        intif_wis_message(sd, target, message, strlen(message) + 1);
        return;
    }

    // Check if target is ignoring whispers
    if (dstsd->state.ignoreAll &&
        pc_get_group_level(sd) <= pc_get_group_level(dstsd)) {
        clif_wis_end(*sd, ACKWHISPER_ALL_IGNORED);
        return;
    }

    // Check if target is in autotrade
    if (dstsd->state.autotrade == 1) {
        // Send notification...
        return;
    }

    // Send whisper to target
    clif_wis_message(dstsd, sd->status.name, message,
                     strlen(message) + 1, 0);
}
```

### 3. Party Chat Flow

```
Client                    Map Server              Inter-Server           Other Party Members
  |                            |                         |                         |
  |--[0x0108: "Name : Msg"]-->|                         |                         |
  |                            |                         |                         |
  |                            |--[Validate message]     |                         |
  |                            |                         |                         |
  |                            |--[0x3027: Guild ID, Msg]->                        |
  |                            |  (Inter-server packet)  |                         |
  |                            |                         |--[Broadcast to party]-->|
  |                            |<--[Recv party message]--|                         |
  |<--[0x0109: AID + Msg]-----|                         |                         |
  |                            |--[0x0109: AID + Msg]------------------------>|
  |                            |                         |                         |
```

**Handler Implementation:**
```c
void clif_parse_PartyMessage(int32 fd, map_session_data* sd)
{
    char name[NAME_LENGTH], message[CHAT_SIZE_MAX],
         output[CHAT_SIZE_MAX+NAME_LENGTH*2];

    // Validate packet and retrieve name and message
    if (!clif_process_message(sd, false, name, message, output))
        return;

    // Send to party system (handles inter-server communication)
    party_send_message(sd, output, strlen(output) + 1);
}
```

### 4. Guild Chat Flow

```
Client                    Map Server              Inter-Server           Other Guild Members
  |                            |                         |                         |
  |--[0x017e: "Name : Msg"]-->|                         |                         |
  |                            |                         |                         |
  |                            |--[Validate message]     |                         |
  |                            |                         |                         |
  |                            |--[If BG, use BG chat]   |                         |
  |                            |--[Else, guild chat]     |                         |
  |                            |                         |                         |
  |                            |--[0x3027: Guild ID, Msg]->                        |
  |                            |  (Inter-server packet)  |                         |
  |                            |                         |--[Broadcast to guild]-->|
  |<--[0x017f: Msg]-----------|                         |                         |
  |                            |--[0x017f: Msg]----------------------->|
  |                            |                         |                         |
```

**Handler Implementation:**
```c
void clif_parse_GuildMessage(int32 fd, map_session_data* sd)
{
    char name[NAME_LENGTH], message[CHAT_SIZE_MAX],
         output[CHAT_SIZE_MAX+NAME_LENGTH*2];

    // Validate packet and retrieve name and message
    if (!clif_process_message(sd, false, name, message, output))
        return;

    // Check if in battleground, use BG chat instead
    if (sd->bg_id)
        bg_send_message(sd, output, strlen(output));
    else
        guild_send_message(sd, output, strlen(output));
}
```

## Message Validation

All chat messages go through `clif_process_message` for validation and sanitization:

```c
static bool clif_process_message(map_session_data* sd, bool whisperFormat,
                                 char* out_name, char* out_message,
                                 char* out_full_message)
{
    const char* separator = " : ";
    int32 fd = sd->fd;
    struct s_packet_db* info = &packet_db[RFIFOW(fd, 0)];

    uint16 packetLength = RFIFOW(fd, info->pos[0]);
    const char *input = RFIFOCP(fd, info->pos[1]);

    // 1. Basic structure check (minimum 4-byte header)
    if (packetLength < 4) {
        ShowWarning("clif_process_message: Malformed packet (no message data)\n");
        return false;
    }

    uint16 inputLength = packetLength - 4;

    // 2. Process name part
    if (whisperFormat) {
        // Whisper: name has fixed width (NAME_LENGTH = 24)
        if (inputLength < NAME_LENGTH + 1) {
            ShowWarning("clif_process_message: Packet length incorrect\n");
            return false;
        }

        const char* name = input;
        size_t nameLength = strnlen(name, NAME_LENGTH - 1);

        // Name must be zero-terminated
        if (name[nameLength] != '\0') {
            ShowWarning("clif_process_message: Unterminated name\n");
            return false;
        }

        message = input + NAME_LENGTH;
        messageLength = inputLength - NAME_LENGTH;
    } else {
        // Normal chat: "CharName : Message"
        size_t separatorLength = strnlen(separator, NAME_LENGTH);
        size_t nameLength = strnlen(sd->status.name, NAME_LENGTH - 1);

        // Check sufficient data
        if (inputLength < nameLength + separatorLength + 1) {
            ShowWarning("clif_process_message: No username data\n");
            return false;
        }

        const char* name = input;

        // Validate: must start with speaker's name + separator
        if (strncmp(name, sd->status.name, nameLength) ||
            strncmp(name + nameLength, separator, separatorLength)) {
            ShowWarning("clif_process_message: Incorrect name! Forcing relog.\n");
            set_eof(sd->fd);  // Kick to correct desynch
            return false;
        }

        message = input + nameLength + separatorLength;
        messageLength = inputLength - nameLength - separatorLength;
    }

    // 3. Message length validation
#if PACKETVER < 20151001
    // Old clients: message must be zero-terminated
    if (messageLength != strnlen(message, messageLength) + 1) {
        ShowWarning("clif_process_message: Length incorrect\n");
        return false;
    }

    if (message[messageLength - 1] != '\0') {
        ShowWarning("clif_process_message: Unterminated message\n");
        return false;
    }
#else
    // New clients: no zero termination
    messageLength += 1;
#endif

    // 4. Maximum length check
    if (messageLength > CHAT_SIZE_MAX - 1) {
        ShowWarning("clif_process_message: Message too long\n");
        return false;
    }

    // Copy validated data to output parameters
    safestrncpy(out_name, name, NAME_LENGTH);
    safestrncpy(out_message, message, messageLength);
    safesnprintf(out_full_message, CHAT_SIZE_MAX + NAME_LENGTH*2,
                 "%s%s%s", name, separator, message);

    return true;
}
```

**Validation Checks:**
1. **Packet length** - Must be at least 4 bytes (header)
2. **Name validation** - For normal chat, name must match sender
3. **Name termination** - Names must be null-terminated
4. **Message length** - Must not exceed CHAT_SIZE_MAX (255 + 1 = 256 bytes)
5. **Message termination** - Depends on PACKETVER (older versions require null termination)
6. **Separator validation** - Normal chat must have " : " separator

## Send Targets

The `send_target` enum defines message broadcast scopes:

```c
enum send_target {
    ALL_CLIENT = 0,        // All connected players
    ALL_SAMEMAP,           // All players on same map

    AREA,                  // Area around sender
    AREA_WOS,              // Area without self
    AREA_WOC,              // Area without chatrooms
    AREA_WOSC,             // Area without own chatroom
    AREA_CHAT_WOC,         // Hearable area without chatrooms

    CHAT,                  // Current chatroom
    CHAT_WOS,              // Chatroom without self

    PARTY,                 // All party members
    PARTY_WOS,             // Party without self
    PARTY_SAMEMAP,         // Party members on same map
    PARTY_SAMEMAP_WOS,     // Party on same map without self
    PARTY_AREA,            // Party in area
    PARTY_AREA_WOS,        // Party in area without self

    GUILD,                 // All guild members
    GUILD_WOS,             // Guild without self
    GUILD_SAMEMAP,         // Guild members on same map
    GUILD_SAMEMAP_WOS,     // Guild on same map without self
    GUILD_NOBG,            // Guild excluding battleground members

    BG,                    // Battleground team
    BG_WOS,                // BG team without self
    BG_SAMEMAP,            // BG team on same map
    BG_SAMEMAP_WOS,        // BG team on same map without self
    BG_AREA,               // BG team in area
    BG_AREA_WOS,           // BG team in area without self

    CLAN,                  // All clan members

    DUEL,                  // Duel participants
    DUEL_WOS,              // Duel without self

    SELF,                  // Only sender
    // ... and more
};
```

## Broadcasting Functions

### Normal Chat Broadcast
```c
void clif_GlobalMessage(block_list& bl, const char* message,
                       enum send_target target)
{
    nullpo_retv(message);

    int16 len = (int16)(strlen(message) + 1);

    // Truncate if too long
    if (len > CHAT_SIZE_MAX) {
        ShowWarning("clif_GlobalMessage: Truncating message (len=%d).\n", len);
        len = CHAT_SIZE_MAX;
    }

    PACKET_ZC_NOTIFY_CHAT* p =
        reinterpret_cast<PACKET_ZC_NOTIFY_CHAT*>(packet_buffer);

    p->PacketType = HEADER_ZC_NOTIFY_CHAT;  // 0x008d
    p->PacketLength = sizeof(*p) + len;
    p->GID = bl.id;
    safestrncpy(p->Message, message, len);

    clif_send(p, p->PacketLength, &bl, target);
}
```

### Whisper Message
```c
void clif_wis_message(map_session_data* sd, const char* nick,
                     const char* mes, size_t mes_len, int32 gmlvl)
{
    PACKET_ZC_WHISPER* p =
        reinterpret_cast<PACKET_ZC_WHISPER*>(packet_buffer);

    p->PacketType = HEADER_ZC_WHISPER;  // 0x0097 or 0x09de
    p->PacketLength = sizeof(*p) + mes_len;

    safestrncpy(p->sender, nick, NAME_LENGTH);

#if defined(PACKETVER_MAIN_NUM) && PACKETVER_MAIN_NUM >= 20131204
    p->senderGID = sd->status.account_id;
    p->isAdmin = (gmlvl > 0) ? 1 : 0;
#elif defined(PACKETVER_RE_NUM) && PACKETVER_RE_NUM >= 20131120
    p->isAdmin = gmlvl;
#endif

    safestrncpy(p->message, mes, mes_len);

    clif_send(p, p->PacketLength, &sd->bl, SELF);
}
```

## Inter-Server Communication

### Whisper Between Map Servers

```c
int32 intif_wis_message(map_session_data *sd, char *nick,
                       char *mes, size_t mes_len)
{
    int32 headersize = 8 + 2 * NAME_LENGTH;

    nullpo_ret(sd);

    if (CheckForCharServer())
        return 0;

    // No other map servers, target is offline
    if (other_mapserver_count < 1) {
        clif_wis_end(*sd, ACKWHISPER_TARGET_OFFLINE);
        return 0;
    }

    // Build inter-server whisper packet
    WFIFOHEAD(inter_fd, mes_len + headersize);
    WFIFOW(inter_fd, 0) = 0x3001;  // Inter-server whisper packet
    WFIFOW(inter_fd, 2) = (int16)(mes_len + headersize);
    WFIFOL(inter_fd, 4) = pc_get_group_level(sd);  // GM level
    safestrncpy(WFIFOCP(inter_fd, 8), sd->status.name, NAME_LENGTH);
    safestrncpy(WFIFOCP(inter_fd, 8 + NAME_LENGTH), nick, NAME_LENGTH);
    safestrncpy(WFIFOCP(inter_fd, 8 + 2*NAME_LENGTH), mes, mes_len);
    WFIFOSET(inter_fd, WFIFOW(inter_fd, 2));

    if (battle_config.etc_log)
        ShowInfo("intif_wis_message from %s to %s (message: '%s')\n",
                 sd->status.name, nick, mes);

    return 1;
}
```

### Guild Message Broadcasting

```c
int32 guild_send_message(map_session_data *sd, const char *mes, size_t len)
{
    nullpo_ret(sd);

    if (sd->status.guild_id == 0)
        return 0;

    // Send to inter-server for distribution
    intif_guild_message(sd->status.guild_id, sd->status.account_id, mes, len);

    // Also send to local guild members
    guild_recv_message(sd->status.guild_id, sd->status.account_id, mes, len);

    // Chat logging
    log_chat(LOG_CHAT_GUILD, sd->status.guild_id, sd->status.char_id,
             sd->status.account_id, mapindex_id2name(sd->mapindex),
             sd->x, sd->y, nullptr, mes);

    return 1;
}
```

## Special Features

### 1. NPC Whisper Commands
Players can whisper to NPCs using the format `NPC:NpcName`:
```c
if (target[0] && (strncasecmp(target, "NPC:", 4) == 0) &&
    (strlen(target) > 4)) {
    char* str = target + 4;  // Skip "NPC:" prefix
    npc_data* npc = npc_name2id(str);
    if (npc) {
        // Execute NPC script with message as parameter
        // ...
    }
}
```

### 2. Custom Channels
Players can be bound to custom channels with specific permissions:
```c
if (sd->gcbind &&
    ((sd->gcbind->opt & CHAN_OPT_CAN_CHAT) ||
     pc_has_permission(sd, PC_PERM_CHANNEL_ADMIN))) {
    channel_send(sd->gcbind, sd, message);
    return;
}
```

### 3. Chat Logging
All chat types are logged for auditing:
```c
// Log types
enum e_log_chat_type {
    LOG_CHAT_GLOBAL,
    LOG_CHAT_WHISPER,
    LOG_CHAT_PARTY,
    LOG_CHAT_GUILD,
    LOG_CHAT_CLAN,
    // ...
};

log_chat(LOG_CHAT_WHISPER, 0, sd->status.char_id,
         sd->status.account_id, mapindex_id2name(sd->mapindex),
         sd->x, sd->y, target, message);
```

### 4. Ignore/Block System
Players can ignore whispers from specific players or all players:
```c
// Check if target ignores everyone
if (dstsd->state.ignoreAll &&
    pc_get_group_level(sd) <= pc_get_group_level(dstsd)) {
    if (pc_isinvisible(dstsd) &&
        pc_get_group_level(sd) < pc_get_group_level(dstsd))
        clif_wis_end(*sd, ACKWHISPER_TARGET_OFFLINE);
    else
        clif_wis_end(*sd, ACKWHISPER_ALL_IGNORED);
    return;
}
```

### 5. Autotrade Protection
Players in autotrade mode cannot receive whispers:
```c
if (dstsd->state.autotrade == 1) {
    safesnprintf(output, sizeof(output),
                 "%s is in autotrade mode and cannot receive whispered messages.",
                 dstsd->status.name);
    clif_wis_message(sd, wisp_server_name, output, strlen(output) + 1, 0);
    return;
}
```

## Implementation Considerations for Aesir

### 1. Packet Handling
- Implement packet parsers for each chat type (0x008c, 0x0096, 0x0108, 0x017e, etc.)
- Register packets in the packet registry
- Handle variable-length packets correctly

### 2. Message Validation
- Port `clif_process_message` to Elixir
- Validate message length (max 256 bytes)
- Validate name format and separator
- Prevent message injection/spoofing

### 3. Broadcasting
- Implement area-based broadcasting for normal chat
- Use Phoenix.PubSub for party/guild/clan chat distribution
- Handle cross-server whispers via inter-server communication

### 4. Session Management
- Track player's chat state (ignoreAll, autotrade, etc.)
- Manage channel bindings
- Track chatroom membership

### 5. Database
- Log chat messages for auditing
- Store ignore lists
- Track chat-related violations

### 6. Security
- Rate limiting to prevent spam
- Profanity filtering (optional)
- GM command detection (messages starting with @)
- SQL injection prevention in logged messages

### 7. Inter-Server Communication
- Use existing PubSub for guild/party/clan messages
- Implement whisper routing between zone servers
- Handle offline player notifications

## Packet Flow Summary

| Chat Type | Client → Server | Server → Client(s) | Scope | Notes |
|-----------|----------------|-------------------|-------|-------|
| Normal | 0x008c | 0x008d | Area | Includes GID and full "Name : Message" |
| Whisper | 0x0096 | 0x0097, 0x0098 | Direct | 0x0098 is acknowledgment |
| Party | 0x0108 | 0x0109 | Party-wide | Includes AID |
| Guild | 0x017e | 0x017f | Guild-wide | May use BG chat if in battleground |
| Battleground | 0x02db | Similar to guild | BG team | Uses BG messaging system |
| Clan | 0x098d | 0x098e | Clan-wide | PACKETVER >= 20131223 |

## References

Key source files from rAthena:
- `src/map/clif.cpp` - Client interface functions
- `src/map/clif.hpp` - Packet definitions and declarations
- `src/map/packets.hpp` - Packet structure definitions
- `src/map/party.cpp` - Party chat implementation
- `src/map/guild.cpp` - Guild chat implementation
- `src/map/battleground.cpp` - Battleground chat
- `src/map/intif.cpp` - Inter-server communication
