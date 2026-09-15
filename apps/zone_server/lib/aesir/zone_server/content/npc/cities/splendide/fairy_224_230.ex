defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.Fairy224230 do
  @moduledoc """
  A fairy invites the player to sing and dance.

  ## Behavior

  - Speaks intelligibly while the Ring of the Ancient Wise King is equipped and the ep13_2_rhea gate is complete; otherwise
    responds in untranslated language.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "splendide",
        x: 224,
        y: 230,
        dir: 3,
        sprite: 440,
        name: "Fairy",
        scope: :shared,
        unique_name: "Fairy#13_2_8"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Fairy]")
      |> mes("Listen carefully and learn more!")
      |> mes("Let's sing and dance!")
      |> mes("You can be part of us!")
      |> mes("Shake your hips!")
      |> mes("Wow~Woo~Wow~")
      |> mes("Dance~!")
      |> close()
    else
      ctx
      |> mes("[Fairy]")
      |> mes("NuffMushLars Ra WehVilnah Ra DielWeh")
      |> mes("RivehnarWos Ra YurSharRe")
      |> mes("TalVaThor O VerWhatas")
      |> mes("FuloDimIyaz Mu WhaNoreo U ")
      |> mes("AlahNeLo Ra UorOsa")
      |> mes("SeAnduMush Ur ")
      |> close()
    end
  end
end
