<script lang="ts">
	import Skeleton from './Skeleton.svelte';
	import { twMerge } from 'tailwind-merge';

	interface Props {
		items?: number;
		showAvatar?: boolean;
		showAction?: boolean;
		class?: string;
	}

	let { items = 5, showAvatar = true, showAction = false, class: className }: Props = $props();
</script>

<div class={twMerge('flex flex-col divide-y dark:divide-gray-700', className)}>
	{#each Array(items) as _, i (i)}
		<div class="flex items-center gap-4 py-4">
			{#if showAvatar}
				<Skeleton variant="avatar" />
			{/if}

			<div class="flex flex-1 flex-col gap-2">
				<Skeleton variant="text" width="50%" />
				<Skeleton variant="text" width="30%" height="12px" />
			</div>

			{#if showAction}
				<Skeleton variant="button" width="70px" height="32px" />
			{/if}
		</div>
	{/each}
</div>
