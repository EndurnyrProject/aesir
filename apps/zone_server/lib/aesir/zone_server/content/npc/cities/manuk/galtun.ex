defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Galtun do
  @moduledoc """
  Shares a Manuk resident's remarks according to whether the visitor understands the local language.

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
        map: "manuk",
        x: 218,
        y: 163,
        dir: 3,
        sprite: 450,
        name: "Galtun",
        scope: :shared,
        unique_name: "Galtun#ep13_2_1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Galtun]")
      |> mes("Recently, tiny things have been flying around.")
      |> mes("I am not sure if they are flies or not.")
      |> mes("But it is very annoying.")
      |> next()
      |> mes("[Galtun]")
      |> mes("They can only use their small magic from a long distance.")
      |> mes("But I can kick them off quickly.")
      |> mes("They are so bothersome. But I better not waste my time with them.")
      |> close()
    else
      ctx
      |> mes("[Galtun]")
      |> mes("Ya sda sdou sh dbi")
      |> mes("Av bu dgs ldo gp gf ")
      |> mes("Jg gfs dsd fw eerr ")
      |> next()
      |> mes("[Galtun]")
      |> mes("Mb ih ids oj fd")
      |> mes("Pg sdf dd sd fff")
      |> mes("Bq wer jfsd fsd ut yy")
      |> mes("Nx cxd fsd fs df ")
      |> close()
    end
  end
end
