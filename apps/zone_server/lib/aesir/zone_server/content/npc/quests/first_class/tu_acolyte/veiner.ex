defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuAcolyte.Veiner do
  @moduledoc """
  Veiner, an exhausted convent worker who receives a chocolate delivery during the Acolyte
  training quest.

  ## Behavior

  - On the first delivery step, takes the Merchant Box (handmade chocolate from his sweetheart)
    and advances the quest.
  - After the delivery he swoons over his sweetheart; before it he asks for help carrying
    his things.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Capuche
    - Euphy
    - Daegaladh
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "prt_monk", x: 197, y: 228, dir: 3, sprite: 89, name: "Veiner", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Veiner]")

    ctx =
      cond do
        Rathena.truthy?(count_item(ctx, 1081)) and get_char_var(ctx, :tu_acolyte01, 0) == 18 ->
          receive_chocolate(ctx)

        get_char_var(ctx, :tu_acolyte01, 0) > 18 ->
          ctx
          |> mes("I can't wait")
          |> mes("to see her again!")
          |> mes("Bibi...! I loooove you!")
          |> emotion(:chupchup)

        true ->
          ctx
          |> mes("So very")
          |> mes("exhausted...")
          |> mes("Would you help")
          |> mes("me carry my stuff?")
          |> mes("P-please...")
      end

    close(ctx)
  end

  defp receive_chocolate(ctx) do
    ctx
    |> mes("So very exhausted...")
    |> mes("Should I just go back home?")
    |> next()
    |> mes("[Veiner]")
    |> mes("What's that?")
    |> mes("You have a delivery")
    |> mes("for me? Why, what")
    |> mes("ever could it be?")
    |> next()
    |> mes("[Veiner]")
    |> mes("This is...!")
    |> mes("It's Handmade Chocolate")
    |> mes("from my honey bunny!")
    |> mes("Oh Bibi! You're the best!")
    |> specialeffect(:vallentine)
    |> specialeffect(:heartcasting)
    |> next()
    |> mes("[Veiner]")
    |> mes("Oh right!")
    |> mes(
      "Thank you very much for delivering this to me. Sorry, but I'm always excited to hear from my cutie pie~"
    )
    |> emotion(:thanks)
    |> set_char_var(:tu_acolyte01, 19)
    |> delitem(1081, 1)
  end
end
