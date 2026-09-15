defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.Fairy22336 do
  @moduledoc """
  A fairy vows to fight for the Laphine despite disliking combat.

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
        x: 223,
        y: 36,
        dir: 3,
        sprite: 462,
        name: "Fairy",
        scope: :shared,
        unique_name: "Fairy#13_2_9"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Fairy]")
      |> mes("I don't want to touch them at all.")
      |> mes("But they are ruining my Yggdrasilberries.")
      |> mes("I can't stand it anymore!")
      |> next()
      |> mes("[Fairy]")
      |> mes("Fighting is not my thing...")
      |> mes("But for our glory, I will fight!")
      |> mes("They should feel honored to be battling with us!")
      |> close()
    else
      ctx
      |> mes("[Fairy]")
      |> mes("AshAmanNei Ir LonVeldremu O ")
      |> mes("AnduSarHir No NudAnumaur Ha Veld")
      |> mes("Semarmah U VeTingDieb Yu ")
      |> mes("mahsertas Ra marAmanAdor Ir ")
      |> next()
      |> mes("[Fairy]")
      |> mes("TingAgolLu So MushAndumah U neseor")
      |> mes("WhaDuFulo er ImanThusNe Di Tur")
      |> mes("DathUornah Ir MemaurDeh Yu Fulo")
      |> mes("CyaMeDor Ko VeLarsAgol")
      |> close()
    end
  end
end
