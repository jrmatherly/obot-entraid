<script lang="ts">
	import { twMerge } from 'tailwind-merge';
	import Skeleton from './Skeleton.svelte';

	interface Props {
		showAvatar?: boolean;
		showImage?: boolean;
		lines?: number;
		class?: string;
	}

	let { showAvatar = false, showImage = false, lines = 3, class: className }: Props = $props();
</script>

<div
	class={twMerge(
		'dark:bg-surface2 dark:border-surface3 flex flex-col gap-4 rounded-xl border bg-white p-4 shadow-sm',
		className
	)}
>
	{#if showImage}
		<Skeleton variant="rectangular" height="120px" class="w-full" />
	{/if}

	{#if showAvatar}
		<div class="flex items-center gap-3">
			<Skeleton variant="avatar" />
			<div class="flex flex-1 flex-col gap-2">
				<Skeleton variant="text" width="60%" />
				<Skeleton variant="text" width="40%" height="12px" />
			</div>
		</div>
	{/if}

	<Skeleton variant="text" {lines} />

	{#if !showAvatar && !showImage}
		<div class="flex gap-2">
			<Skeleton variant="button" width="80px" />
			<Skeleton variant="button" width="80px" />
		</div>
	{/if}
</div>
