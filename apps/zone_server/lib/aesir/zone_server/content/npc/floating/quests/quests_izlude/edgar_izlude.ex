defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsIzlude.EdgarIzlude do
  @moduledoc """
  Izlude ship captain Edgar, who offers a discounted 250 Zeny passage to Alberta.

  The script has no placement of its own; the renewal and pre-renewal Izlude Edgar NPCs
  duplicate it.

  ## Behavior

  - First talk: chats about Alberta and Phelix, then offers directions; asking to sail while
    broke unlocks the 250 Zeny passage
  - Accepting the offer sets bit 16 of `MISC_QUEST` before the Zeny check, so the discount is
    remembered even when the player cannot pay yet
  - With bit 16 set, Edgar offers the passage straight away
  - Paying takes 250 Zeny and warps the player to Alberta (195, 164); without 250 Zeny he
    closes without charging

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{name: "", unique_name: "Edgar_izlude"},
      %{
        map: "izlude",
        x: 179,
        y: 219,
        dir: 2,
        sprite: 49,
        name: "Edgar",
        scope: :renewal,
        unique_name: "Edgar#izlude"
      },
      %{
        map: "izlude",
        x: 182,
        y: 186,
        dir: 2,
        sprite: 49,
        name: "Edgar",
        scope: :pre_renewal,
        unique_name: "Edgar#izlude"
      },
      %{
        map: "izlude_a",
        x: 179,
        y: 219,
        dir: 2,
        sprite: 49,
        name: "Edgar",
        scope: :renewal,
        unique_name: "Edgar#izlude_a"
      },
      %{
        map: "izlude_b",
        x: 179,
        y: 219,
        dir: 2,
        sprite: 49,
        name: "Edgar",
        scope: :renewal,
        unique_name: "Edgar#izlude_b"
      },
      %{
        map: "izlude_c",
        x: 179,
        y: 219,
        dir: 2,
        sprite: 49,
        name: "Edgar",
        scope: :renewal,
        unique_name: "Edgar#izlude_c"
      },
      %{
        map: "izlude_d",
        x: 179,
        y: 219,
        dir: 2,
        sprite: 49,
        name: "Edgar",
        scope: :renewal,
        unique_name: "Edgar#izlude_d"
      }
    ]

  @discount_bit 16
  @fare 250

  @impl true
  def on_talk(ctx) do
    if :erlang.band(get_char_var(ctx, :MISC_QUEST, 0), @discount_bit) != 0 do
      returning_passenger(ctx)
    else
      first_meeting(ctx)
    end
  end

  defp returning_passenger(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Edgar]")
      |> mes(
        "So are you heading to Alberta again? Let me give you the same discount and only charge 250 Zeny, just like the last time."
      )
      |> mes("How's that sound?")
      |> next()
      |> select(["Alrighty~!", "Why are you being so nice to me?!"])

    case choice do
      1 ->
        sail(ctx, ["Why don't you go", "get some more cash?"])

      _ ->
        ctx
        |> mes("[Edgar]")
        |> mes(
          "It's just the way I am. That, and your devilish smile reminds me of my beloved blond haired son who left home years ago to become a Sailor on his own ship. Bless his soul, wherever he is."
        )
        |> close()
    end
  end

  defp first_meeting(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Edgar]")
      |> mes(
        "My town, Izlude, is connected to Alberta by the harbor in the West. There is so much traffic between us, I almost become an Albertian.  Hehehe~"
      )
      |> next()
      |> mes("[Edgar]")
      |> mes(
        "There's this guy I know pretty well, Phelix, who lives in Alberta. That guy is really stingy... He charges for everything!"
      )
      |> next()
      |> mes("[Edgar]")
      |> mes(
        "But he's really a nice guy and likes helping other people. He has a good heart and will give you his support if you meet his price."
      )
      |> next()
      |> mes("[Edgar]")
      |> mes(
        "Lately, people in Alberta say that he is really trying to help folks and that his demand for Jellopies is just a coverup.  Well, you should take a look at what he has to offer."
      )
      |> next()
      |> select(["Can you tell me how to get to Alberta?", "End Conversation"])

    case choice do
      1 -> directions(ctx)
      _ -> ctx |> mes("[Edgar]") |> mes("Yeah, alright.") |> mes("See you later~") |> close()
    end
  end

  defp directions(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Edgar]")
      |> mes(
        "Huh? Well, you can use your feet and just walk.  But if you have money, I'd like to suggest that you take a ship."
      )
      |> next()
      |> select(["Okay, gotcha.", "But I'm sick of walking and I'm broke!"])

    case choice do
      1 -> ctx |> mes("[Edgar]") |> mes("Alrighty, take care~") |> close()
      _ -> discount_offer(ctx)
    end
  end

  defp discount_offer(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Edgar]")
      |> mes("Okay...")
      |> mes(
        "You don't want to walk AND you've got no cash, but you still want to go there? Oh geez..."
      )
      |> next()
      |> mes("[Edgar]")
      |> mes(
        "Fine fine. Me, being the captain of a ship, can afford to bring you there at a lower price. How does 250 Zeny sound?"
      )
      |> next()
      |> select(["Alrighty~!", "Bah, what a rip off!!"])

    case choice do
      1 ->
        ctx
        |> set_char_var(
          :MISC_QUEST,
          :erlang.bor(get_char_var(ctx, :MISC_QUEST, 0), @discount_bit)
        )
        |> sail(["Go and get", "some more."])

      _ ->
        ctx
        |> mes("[Edgar]")
        |> mes("Boy oh boy,")
        |> mes("if you think")
        |> mes("that's a rip off...")
        |> close()
    end
  end

  defp sail(ctx, [first_line, second_line]) do
    if zeny(ctx) < @fare do
      ctx
      |> mes("[Edgar]")
      |> mes("Um...")
      |> mes("This isn't")
      |> mes("enough money.")
      |> mes(first_line)
      |> mes(second_line)
      |> close()
    else
      ctx |> pay_zeny(@fare) |> warp("alberta", 195, 164)
    end
  end
end
