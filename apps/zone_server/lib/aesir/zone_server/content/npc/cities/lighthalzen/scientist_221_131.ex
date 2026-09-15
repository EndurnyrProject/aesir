defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Scientist221131 do
  @moduledoc """
  Reports on laboratory work according to the visitor's disguise and quest progress.

  ## Behavior

  - Discusses processing results with disguised visitors before the quest threshold.
  - Reports ruined machines after the hg_tre character variable exceeds 54.
  - Calls for guards and warps undisguised visitors out.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 221,
        y: 131,
        dir: 7,
        sprite: 865,
        name: "Scientist",
        scope: :shared,
        unique_name: "Scientist#li_01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      not Rathena.truthy?(is_equipped(ctx, 2241)) or
          not Rathena.truthy?(is_equipped(ctx, 2243)) ->
        ctx
        |> mes("[Scientist]")
        |> mes("What?! Guards!")
        |> mes("Hurry, there's an")
        |> mes("intruder right here!")
        |> emotion(:surprise)
        |> close()
        |> warp("lhz_in01", 33, 224)

      get_char_var(ctx, :hg_tre, 0) > 54 ->
        ctx
        |> mes("[A Scientist]")
        |> mes(
          "What happened? All the machines are ruined and the research report are gone! The history of Regenschirm has been hacked!"
        )
        |> close()

      true ->
        ctx
        |> mes("[Scientist]")
        |> mes("It takes so long for")
        |> mes("this device to process")
        |> mes("all the data and give me")
        |> mes("the results. Still, the wait")
        |> mes("heightens my anticipation...")
        |> close()
    end
  end
end
