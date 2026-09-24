defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Assassin.MazeAssistant do
  @moduledoc """
  Entrance to the Guildmaster's maze of the Assassin job test.

  ## Behavior

  - Applicants arriving from the hiding test are returned to the maze start while their
    quest step advances.
  - Anyone else is announced, has their respawn point saved, and enters the Guildmaster's room.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe)
    - kobra_k88
    - Lupus
    - Vicious
    - Silent
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Zephyrus_cr
    - brianluau
    - Kisuka
    - JayPee
    - Euphy
    - MrAntares
    - Atemo

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_moc_16",
        x: 182,
        y: 169,
        dir: 0,
        sprite: 45,
        name: "Maze Assistant",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    if get_char_var(ctx, :ASSIN_Q, 0) == 5 or get_char_var(ctx, :ASSIN_Q, 0) == 6 do
      ctx = warp(ctx, "in_moc_16", 181, 183)
      ctx = set_char_var(ctx, :ASSIN_Q, get_char_var(ctx, :ASSIN_Q, 0) + 1)

      if Rathena.truthy?(isbegin_quest(ctx, 8006)) do
        ctx
      else
        changequest(ctx, 8005, 8006)
      end
    else
      ctx
      |> mapannounce("in_moc_16", "#{char_name(ctx, 0)} has entered 'Guildmaster's room.'", 1)
      |> savepoint("in_moc_16", 181, 183)
      |> donpcevent("Guildmaster#ASN1::OnCast")
      |> warp("in_moc_16", 167, 113)
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
