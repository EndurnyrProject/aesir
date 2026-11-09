defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.QueJob01 do
  @moduledoc """
  Jack's hideout entrance in eastern Morocc, which only lets Assassins through without a
  word.

  ## Behavior

  - Warps an Assassin straight into the hideout on touch and on talk.
  - Explains the entrance to everyone else and then warps them in as well.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc",
        x: 45,
        y: 110,
        dir: 0,
        sprite: 45,
        name: "que_job01",
        scope: :shared,
        unique_name: "que_job01#01",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @hideout {"que_job01", 9, 94}

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx), do: enter(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: enter(ctx)

  defp enter(ctx) do
    if Rathena.job_id(base_class(ctx)) == Rathena.job_id(:assassin) do
      send_to_hideout(ctx)
    else
      jack_explains(ctx)
    end
  end

  defp jack_explains(ctx) do
    ctx
    |> mes("[Jack]")
    |> mes("Oh, not everyone can enter that place...!")
    |> mes("...")
    |> mes("Nevermind.")
    |> next()
    |> mes("[Jack]")
    |> mes("Since everything has changed,")
    |> mes("just feel free to enter wherever you want!")
    |> close()
    |> send_to_hideout()
  end

  defp send_to_hideout(ctx),
    do: warp(ctx, elem(@hideout, 0), elem(@hideout, 1), elem(@hideout, 2))
end
