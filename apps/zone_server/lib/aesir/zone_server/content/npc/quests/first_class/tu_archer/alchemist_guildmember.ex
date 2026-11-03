defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuArcher.AlchemistGuildmember do
  @moduledoc """
  Alchemist Guild member who buys Flora drops to restore the guild's ruined Flora field.

  ## Behavior

  - Once the Archer errand has started, buys every Maneater Blossom for 130 Zeny and every
    Stem for 30 Zeny in one go, or explains what the guild needs when the player has none.
  - Before the errand starts he only sighs about the guild's crisis.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - L0ne_W0lf
    - SinSloth
    - Capuche
    - Euphy
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "pay_arche",
        x: 130,
        y: 113,
        dir: 3,
        sprite: 740,
        name: "Alchemist Guildmember",
        scope: :shared,
        unique_name: "Alchemist Guildmember#tu"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @maneater_blossom 1032
  @stem 905

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Alchemist Guildmember]")

    cond do
      get_char_var(ctx, :tu_archer02, 0) <= 0 ->
        sigh(ctx)

      count_item(ctx, @maneater_blossom) > 0 or count_item(ctx, @stem) > 0 ->
        offer_purchase(ctx)

      true ->
        explain_flora_field(ctx)
    end
  end

  defp offer_purchase(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Great...!")
      |> mes("I've been waiting")
      |> mes("for the Icarus Guild")
      |> mes("to send somebody")
      |> mes("to help us! Finally!")
      |> emotion(:cry)
      |> next()
      |> mes("[Alchemist Guildmember]")
      |> mes("Would you like to sell ^3131FFStems^000000")
      |> mes("and ^3131FFManeater Blossoms^000000 to")
      |> mes("the Alchemist Guild? We'll buy")
      |> mes("each Stem for ^3131FF30 Zeny^000000 and each")
      |> mes("Maneater Blossom for ^3131FF130 Zeny^000000.")
      |> next()
      |> select(["Sell all Stems and Maneater Blossoms", "Don't sell anything."])

    case choice do
      1 ->
        ctx
        |> mes("[Alchemist Guildmember]")
        |> mes("Thank you very much!")
        |> mes("This will really help")
        |> mes("us in maintaining our")
        |> mes("Flora field! I really")
        |> mes("appreciate your help~")
        |> buy_flora()

      2 ->
        ctx
        |> mes("[Alchemist Guildmember]")
        |> mes("Seriously...")
        |> mes("I'm on the verge of begging!")
        |> mes(
          "The Alchemist Guild really needs lots of new supplies to keep our Flora field running!"
        )
        |> emotion(:cry)
        |> close()

      _ ->
        sigh(ctx)
    end
  end

  defp buy_flora(ctx) do
    blossoms = count_item(ctx, @maneater_blossom)
    stems = count_item(ctx, @stem)
    total_zeny = blossoms * 130 + stems * 30

    ctx =
      if Rathena.truthy?(count_item(ctx, @maneater_blossom)),
        do: delitem(ctx, @maneater_blossom, blossoms),
        else: ctx

    ctx = if Rathena.truthy?(count_item(ctx, @stem)), do: delitem(ctx, @stem, stems), else: ctx

    ctx
    |> credit_zeny(total_zeny)
    |> close()
  end

  defp explain_flora_field(ctx) do
    ctx
    |> mes("I don't know if you've heard")
    |> mes("from Kavaruk, but our Flora field is getting ruined by stray cats.")
    |> emotion(:cry)
    |> next()
    |> mes("[Alchemist Guildmember]")
    |> mes("No matter how much we chase")
    |> mes(
      "them away, they always manage to come back. We really have no choice but to replace what they destroy."
    )
    |> next()
    |> mes("[Alchemist Guildmember]")
    |> mes(
      "We'll reward you if you can bring us ^3131FFStems^000000 and ^3131FFManeater Blossoms^000000"
    )
    |> mes(
      "to help us in our field maintenance efforts. These Flora are crucial since they provide funds for our guild. Without them..."
    )
    |> close()
  end

  defp sigh(ctx) do
    ctx
    |> mes("^666666*Sigh...*^000000")
    |> mes("Isn't anyone coming")
    |> mes("to help us? We're facing")
    |> mes("a really huge crisis here!")
    |> close()
  end
end
