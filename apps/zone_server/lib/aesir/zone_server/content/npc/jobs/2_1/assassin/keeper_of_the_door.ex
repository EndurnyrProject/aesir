defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Assassin.KeeperOfTheDoor do
  @moduledoc """
  Door to the hiding test room, opened once an applicant clears the target test.

  ## Behavior

  - Starts hidden and is shown or hidden again by the test controllers.
  - On touch, resets the hiding test, updates the quest step, and moves the player into
    the hiding test room with a respawn point at the guild entrance.

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
        x: 87,
        y: 137,
        dir: 0,
        sprite: 45,
        name: "Keeper of the Door",
        scope: :shared,
        unique_name: "Keeper of the Door#ASN",
        trigger: {2, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Keeper of the Door#ASN")

  def on_event("OnTouch", ctx) do
    ctx = donpcevent(ctx, "Thomas#ASNTEST::OnDisable")
    next_step = if get_char_var(ctx, :ASSIN_Q, 0) == 3, do: 3, else: 4

    ctx
    |> set_char_var(:ASSIN_Q, next_step)
    |> warp("in_moc_16", 87, 102)
    |> savepoint("in_moc_16", 16, 13)
  end

  def on_event("OnEnable", ctx) do
    ctx
    |> mapannounce(
      "in_moc_16",
      "The door to the next room, at coordinates 87 137, has opened.",
      1
    )
    |> enablenpc("Keeper of the Door#ASN")
  end

  def on_event("OnDisable", ctx), do: disablenpc(ctx, "Keeper of the Door#ASN")

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
