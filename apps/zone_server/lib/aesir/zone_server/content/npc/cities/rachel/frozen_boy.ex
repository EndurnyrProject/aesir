defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.FrozenBoy do
  @moduledoc """
  Examines the mysterious boy frozen in the Ice Cave.

  ## Behavior

  - Displays the frozen boy cut-in during the dialogue and clears it after closing.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Tsuyuki and Harp
    - L0ne_W0lf
    - Lupus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "ice_dun04", x: 33, y: 166, dir: 3, sprite: 925, name: "Frozen Boy", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = cutin(ctx, "ra_sboy.bmp", 2)

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("This boy must be the one who Ktullanux tried to protect.")
      |> next()
      |> mes(
        "- The boy was frozen inside a giant ice pole, and he looks as if he is in sleep rather than dead. -"
      )
      |> next()
      |> mes(
        "- You felt freezing as you come closer to the giant ice pole that held the boy within,"
      )
      |> mes("- but for some reason, you felt a mysterious power from the pole. -")
      |> next()
      |> mes("- The boy appeared to be snowy white, and beautiful from the head to the toe. -")
      |> next()
      |> mes("- You wondered why a young boy had to be confined within this isolated cave, -")
      |> mes(
        "- you instinctively knew that no mage in this world would be able to release him from the ice pole."
      )
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("What happened to this boy?")
    |> close()
    |> cutin("", 255)
  end
end
