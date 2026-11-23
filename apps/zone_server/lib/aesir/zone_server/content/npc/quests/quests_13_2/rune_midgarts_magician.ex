defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.RuneMidgartsMagician do
  @moduledoc """
  Helps the player gather language samples and prepare a translator.

  ## Behavior

  - Requests recorded gems and an unidentified mineral as the investigation advances.
  - Eventually sends the player to deliver the crafted gem.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_camp",
        x: 147,
        y: 256,
        dir: 3,
        sprite: 735,
        name: "Rune-Midgarts Magician",
        scope: :shared,
        unique_name: "Rune-Midgarts Magician#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :ep13_2_rhea, 0) < 4 ->
        ctx
        |> mes("[Magician Whisper]")
        |> mes(
          "To store a tremendous amount of information, well, it's impossible with existing technology."
        )
        |> next()
        |> mes("[Magician Whisper]")
        |> mes(
          "Ancient Rune-Midgarts Kingdom used a some kind of magic onto a magical gem to store large information...Using a gem as a storage..."
        )
        |> next()
        |> mes("[Magician Whisper]")
        |> mes(
          "Oh, pardon me, you have such a comfortable atmosphere and I involuntarily spoke to you. Who might you be?"
        )
        |> close()

      get_char_var(ctx, :ep13_2_rhea, 0) == 4 ->
        {ctx, _} =
          ctx
          |> mes("[Magician Whisper]")
          |> mes(
            "To store a tremendous amount of information, well, it's impossible with existing technology."
          )
          |> next()
          |> mes("[Magician Whisper]")
          |> mes(
            "The Ancient Rune-Midgarts Kingdom used some kind of magic on a magical gem to store large amounts of information... Using a gem as storage..."
          )
          |> next()
          |> mes("[Magician Whisper]")
          |> mes(
            "Oh, pardon me, you have such a comfortable atmosphere and I involuntarily spoke to you. Who might you be?"
          )
          |> next()
          |> select(["Uh, Mr. Dictionary sent..."])

        {ctx, v1} =
          ctx
          |> mes("[Magician Whisper]")
          |> mes(
            "Oh? You mean that Linguist from the Arunafeltz. And that means we need a Recorded Language Sample."
          )
          |> next()
          |> mes("[Magician Whisper]")
          |> mes(
            "Hmmm... Actually, I've buried magical gems which records sound waves with its magical power, near their territory...to gather information about their language."
          )
          |> next()
          |> mes("[Magician Whisper]")
          |> mes(
            "But, Assassins who were in charge of burying those gems... They are working on some other mission, so they can't go and retrieve those gems."
          )
          |> next()
          |> mes("[Magician Whisper]")
          |> mes(
            "Without someone do us a favor and retrieve those gems, there's no way I could give you the sample."
          )
          |> next()
          |> select(["Then should I come back later?", "What if I go and retrieve them?"])

        ctx =
          case v1 do
            1 ->
              ctx =
                ctx
                |> mes("[Magician Whisper]")
                |> mes(".............Sure, you could wait for 100 years...")
                |> next()

              ctx
              |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
              |> mes("What?")
              |> next()
              |> mes("[Magician Whisper]")
              |> mes("Ah, No, No, It's nothing.")
              |> next()

            2 ->
              ctx

            _ ->
              throw({:script_end, ctx})
          end

        ctx
        |> mes("[Magician Whisper]")
        |> mes(
          "If you could do that, it will save us whole lot of time and that'd be good for us! Wouldn't it? Don't you think so?"
        )
        |> next()
        |> mes("[Magician Whisper]")
        |> mes("I belive you've met those two alien races out there?")
        |> mes("Assassins buried Magical Gems near their villages without them noticing.")
        |> next()
        |> mes("[Magician Whisper]")
        |> mes("First Gem is buried under the Mushroom-like structure near Fairy's village.")
        |> next()
        |> mes("[Magician Whisper]")
        |> mes("And the Second Gem is buried under the tree near Giant's village.")
        |> next()
        |> mes("[Magician Whisper]")
        |> mes("Bring back those two gems and that would help me greatly.")
        |> next()
        |> mes("[Magician Whisper]")
        |> mes("Well, I can't force you to do it if you are too busy with other matters...")
        |> next()
        |> mes("[Magician Whisper]")
        |> mes("There's an old saying, The one who's thirsty will dig for a well...")
        |> next()
        |> mes("[Magician Whisper]")
        |> mes("I almost forgot! You should be careful when you dig for the Gem.")
        |> mes("Assassins installed a trap to protect Gems as they bury them.")
        |> completequest(8245)
        |> setquest(8246)
        |> set_char_var(:ep13_2_rhea, 5)
        |> close()

      get_char_var(ctx, :ep13_2_rhea, 0) == 5 ->
        ctx = set_local(ctx, :check_spljew00, checkquest(ctx, 8241))
        ctx = set_local(ctx, :check_manjew00, checkquest(ctx, 8242))

        if get_local(ctx, :check_spljew00, 0) > 0 and get_local(ctx, :check_manjew00, 0) > 0 do
          if count_item(ctx, 7575) > 0 and count_item(ctx, 7576) > 0 do
            ctx
            |> mes("[Magician Whisper]")
            |> mes("Wow, You are back already!")
            |> mes("Well then, let me see them!")
            |> next()
            |> mes("- As you handed over the Gem, -")
            |> mes("- he examined it throughly-")
            |> next()
            |> mes("[Magician Whisper]")
            |> mes("Hmm...")
            |> mes(
              "There's lots of noises caught in, but I think I could extract a voice in no time."
            )
            |> next()
            |> mes("[Magician Whisper]")
            |> mes(
              "I will extract a voice recorded in this gem and send them to the Linguist from Arunafeltz."
            )
            |> next()
            |> mes("[Magician Whisper]")
            |> mes(
              "It looks like there's many kind of convenient machines. Voices I've extracted can be sent directly to the Linguist from Arunafeltz by using this recording machine."
            )
            |> next()
            |> mes("[Magician Whisper]")
            |> mes("So I will be ok by on my own. Thank you for your trouble.")
            |> completequest(8241)
            |> completequest(8242)
            |> completequest(8246)
            |> setquest(8247)
            |> delitem(7575, 1)
            |> delitem(7576, 1)
            |> set_char_var(:ep13_2_rhea, 6)
            |> close()
          else
            ctx
            |> mes("[Magician Whisper]")
            |> mes("Ah, that was quick.")
            |> next()
            |> mes("[Magician Whisper]")
            |> mes(
              "Please give meh the gem. I will extract the voice record inside the gem, then give it to the Linguist from Arunafeltz."
            )
            |> next()
            |> mes("[Magician Whisper]")
            |> mes("...... But.... where's the gem?")
            |> close()
          end
        else
          ctx
          |> mes("[Magician Whisper]")
          |> mes("First Gem is buried under the Mushroom-like structure near Fairy's village.")
          |> next()
          |> mes("[Magician Whisper]")
          |> mes("And the Second Gem is buried under the tree near Giant's village.")
          |> next()
          |> mes("[Magician Whisper]")
          |> mes("Bring back those two gems and that would help me greatly.")
          |> next()
          |> mes("[Magician Whisper]")
          |> mes("Well, I can't force you to do it if you are too busy with other matters...")
          |> next()
          |> mes("[Magician Whisper]")
          |> mes("There's an old saying, The one who's thirsty will dig for a well...")
          |> next()
          |> mes("[Magician Whisper]")
          |> mes("I almost forgot! You should be careful when you dig for the Gem.")
          |> mes("Assassins installed a trap to protect Gems as they bury them.")
          |> close()
        end

      get_char_var(ctx, :ep13_2_rhea, 0) > 5 and get_char_var(ctx, :ep13_2_rhea, 0) < 8 ->
        ctx
        |> mes("[Magician Whisper]")
        |> mes(
          "Well, if you are not busy at the time, please go check how's the Linguist from Arunafeltz's research is coming up."
        )
        |> next()
        |> mes("[Magician Whisper]")
        |> mes(
          "I should be working on extracting voice data and send them to the Linguist from Arunafeltz."
        )
        |> close()

      get_char_var(ctx, :ep13_2_rhea, 0) == 8 ->
        ctx
        |> mes("[Magician Whisper]")
        |> mes("Hmm...There's more data than we thought...")
        |> next()
        |> mes("[Magician Whisper]")
        |> mes(
          "Of course it is a piece of cake to turn data into magical power and put'em into a gem...Most important thing is, I don't know if there's a jewl that has enough storage space to store that much of data..."
        )
        |> next()
        |> mes("[Magician Whisper]")
        |> mes(
          "I heard that cold side of a field outside of the Expedition Camp, ^0000ff Mysterious Ore that can't be found in the Midgard."
        )
        |> next()
        |> mes("[Magician Whisper]")
        |> mes(
          "Only if we could find that ore, it would make this work much easier... What do you think about that? Do you think you could go and find one for me?"
        )
        |> next()
        |> mes("[Magician Whisper]")
        |> mes("While you are gone, I will organize the data to put into the Gem.")
        |> completequest(8249)
        |> setquest(8250)
        |> set_char_var(:ep13_2_rhea, 9)
        |> close()

      get_char_var(ctx, :ep13_2_rhea, 0) == 9 ->
        if count_item(ctx, 6048) > 0 do
          ctx
          |> mes("[Magician Whisper]")
          |> mes("Oh! Is this that ore?")
          |> next()
          |> mes("[Magician Whisper]")
          |> mes(
            "This sure is interesting. It has not been refined yet, but I can sense mysterious power from this ore."
          )
          |> next()
          |> mes("[Magician Whisper]")
          |> mes("It's something like... the special wave with a life force.")
          |> next()
          |> mes("[Magician Whisper]")
          |> mes("Let's test and see see how much magical power it could store.")
          |> next()
          |> mes("- He closed his eyes and chanted a spell -")
          |> mes("- with the ore on his hand. -")
          |> next()
          |> mes("[Magician Whisper]")
          |> mes(
            "Lumos Nox Densaugeo Dissendium Diffindo Engorgio Mobiliarbus Expecto patronum!!!!"
          )
          |> next()
          |> specialeffect(:flasher)
          |> emotion(:surprise)
          |> mes("[Magician Whisper]")
          |> mes("Wow!!! Th, This is unbelievable!")
          |> next()
          |> mes("[Magician Whisper]")
          |> mes(
            "An ore with this much storage space, only a size of fingernail could store both of two languages!"
          )
          |> next()
          |> mes("[Magician Whisper]")
          |> mes("Could you wait for a minute?")
          |> mes(
            "Take some rest while I craft this ore into a gem and put the magical data into it. You look exhausted..."
          )
          |> completequest(8250)
          |> setquest(8251)
          |> delitem(6048, 1)
          |> set_char_var(:ep13_2_rhea, 10)
          |> close()
        else
          ctx
          |> mes("[Magician Whisper]")
          |> mes(
            "I heard that the cold side of the field outside of the Expedition Camp has a Unidentified Mineral that can't be found in Midgard."
          )
          |> next()
          |> mes("[Magician Whisper]")
          |> mes(
            "Only if we could find that ore, it would make this work much easier... What do you think about that? Do you think you could go and find one for me?"
          )
          |> next()
          |> mes("[Magician Whisper]")
          |> mes("While you are gone, I will organize the data to put into the Gem.")
          |> close()
        end

      get_char_var(ctx, :ep13_2_rhea, 0) == 10 ->
        if Enum.random(1..5) == 3 do
          ctx
          |> mes("- His face turned a bit pale, -")
          |> mes("- He looked pleased as he saw you -")
          |> next()
          |> mes("[Magician Whisper]")
          |> mes("Ah! Just in time!")
          |> next()
          |> mes("[Magician Whisper]")
          |> mes("I've just finished infusing the magical power.")
          |> mes(
            "From now on, it's up to the Mechanic Engineer from Schwarzwald to combined this gem with a machine to make it work as a real-time translator."
          )
          |> next()
          |> mes("[Magician Whisper]")
          |> mes("I will ask you one last favor.")
          |> mes("Please deliver this crafted gem to the Mechanic Engineer from Schwarzwald.")
          |> next()
          |> mes("[Magician Whisper]")
          |> mes(
            "I'm really sorry to ask you so many favors..., Ah...I've used up too much magical power...I should rest for a while."
          )
          |> next()
          |> mes("- ^0000ff Received the Crafted Gem ^000000 -")
          |> mes("- ^0000ff from Whisper !!^000000 -")
          |> completequest(8251)
          |> setquest(8252)
          |> set_char_var(:ep13_2_rhea, 11)
          |> close()
        else
          ctx
          |> mes("[Magician Whisper]")
          |> mes("Could you wait for a minute?")
          |> mes(
            "Take some rest while I craft this ore into a gem and put the magical data into it. You look exhausted..."
          )
          |> close()
        end

      get_char_var(ctx, :ep13_2_rhea, 0) == 11 ->
        ctx
        |> mes("[Magician Whisper]")
        |> mes("Please deliver this crafted gem to the Mechanic Engineer from Schwarzwald.")
        |> next()
        |> mes("[Magician Whisper]")
        |> mes(
          "I'm really sorry to ask you so many favors..., Ah...I've used up too much magical power...I should rest for a while."
        )
        |> next()
        |> mes("- He looks so sleepy and said -")
        |> mes("- as he rubbing his closing eyes. -")
        |> close()

      get_char_var(ctx, :ep13_2_rhea, 0) == 12 ->
        ctx
        |> mes("[Magician Whisper]")
        |> mes("How's the translator making process going?")
        |> close()

      get_char_var(ctx, :ep13_2_rhea, 0) > 12 ->
        ctx
        |> mes("[Magician Whisper]")
        |> mes("I've just received a message that the translator is finished!")
        |> next()
        |> mes("[Magician Whisper]")
        |> mes(
          "We are short on the amount just yet, still it will make our advance to the other world easier!"
        )
        |> close()

      true ->
        ctx
        |> mes("[Magician Whisper]")
        |> mes("I've just received a message that the translator is finished!")
        |> next()
        |> mes("[Magician Whisper]")
        |> mes(
          "We are short on the amount just yet, still it will make our advance to the other world easier!"
        )
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
